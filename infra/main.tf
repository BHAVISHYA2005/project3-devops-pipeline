# ===========================================================================
#  Terraform Configuration — AWS Infrastructure for DevOps Pipeline
# ===========================================================================
#  This file provisions the complete AWS infrastructure needed to run
#  the devops-pipeline-app:
#
#    1. Networking:   Default VPC + Security Group
#    2. Compute:      EC2 instance with CodeDeploy agent (via user-data)
#    3. IAM:          Roles for EC2 and CodeDeploy (least privilege)
#    4. Storage:      S3 bucket for deployment revisions
#    5. Deployment:   CodeDeploy application + deployment group
#    6. Networking:   Elastic IP for stable public endpoint
#
#  Usage:
#    cd infra
#    terraform init
#    terraform plan                        # review changes
#    terraform apply -auto-approve         # provision (update suffix first!)
# ===========================================================================

# ---------------------------------------------------------------------------
# Terraform settings
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state stored in S3 — critical for team collaboration.
  # Without this, each engineer would have their own local state file
  # and `terraform apply` could overwrite each other's changes.
  #
  # TODO: Add DynamoDB table for state locking to prevent concurrent applies:
  #   dynamodb_table = "terraform-lock"
  backend "s3" {
    bucket = "devops-pipeline-tfstate"
    key    = "devops-pipeline/terraform.tfstate"
    region = "ap-south-1"
  }
}

provider "aws" {
  region = var.aws_region

  # Default tags applied to EVERY resource Terraform creates.
  # This is the modern alternative to repeating tags blocks everywhere.
  # Useful for cost allocation, ownership tracking, and automated policies.
  default_tags {
    tags = {
      Project     = "devops-pipeline"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# ---------------------------------------------------------------------------
# Networking — use the default VPC (simpler for demo/dev environments)
# ---------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------------------------------------------------------
# Security Group — controls which traffic can reach the EC2 instance
# ---------------------------------------------------------------------------
# In production, you should:
#   1. Restrict SSH to your specific IP (not 0.0.0.0/0)
#   2. Put the EC2 behind an ALB and only expose port 80/443 on the ALB
#   3. Use a VPN or SSM Session Manager instead of SSH entirely

resource "aws_security_group" "ec2_sg" {
  name        = "devops-pipeline-ec2-sg"
  description = "Allow HTTP and SSH for the DevOps pipeline EC2 instance"
  vpc_id      = data.aws_vpc.default.id   # explicitly bind to VPC (best practice)

  # HTTP (port 80) — for future reverse proxy / ALB integration
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Application port — the Node.js app listens on 3000
  ingress {
    description = "App port from anywhere"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH — RESTRICT THIS in production to your IP only!
  ingress {
    description = "SSH (restrict to your IP in production!)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # Allow ALL outbound traffic (needed for apt-get, Docker pull, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "devops-pipeline-ec2-sg" }
}

# ---------------------------------------------------------------------------
# IAM — EC2 instance role (allows EC2 to talk to CodeDeploy and ECR)
# ---------------------------------------------------------------------------
# Why use an instance profile instead of hardcoding AWS keys on the server?
#   - Keys can leak, expire, or be shared accidentally
#   - Instance profiles use temporary credentials rotated automatically
#   - This is the AWS-recommended approach (zero-trust, least privilege)

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_code_deploy_role" {
  name               = "devops-pipeline-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Attach the AWS-managed policy that grants CodeDeploy agent permissions
resource "aws_iam_role_policy_attachment" "ec2_code_deploy" {
  role       = aws_iam_role.ec2_code_deploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

# The instance profile is the "bridge" between an IAM role and an EC2 instance
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "devops-pipeline-instance-profile"
  role = aws_iam_role.ec2_code_deploy_role.name
}

# ---------------------------------------------------------------------------
# EC2 Instance — runs the CodeDeploy agent and Docker containers
# ---------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]   # Canonical (Ubuntu's publisher)
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  # user-data.sh runs once at instance launch — installs Docker and
  # the CodeDeploy agent so the instance is ready to receive deployments.
  user_data = file("${path.module}/user-data.sh")

  # Enable detailed monitoring for better CloudWatch metrics (1-min intervals)
  monitoring = true

  # Protect against accidental termination via `terraform destroy`
  # Remove this or set to false when you actually want to tear down.
  lifecycle {
    prevent_destroy = false   # set to `true` in production!
  }

  tags = {
    Name = "devops-pipeline-server"
  }
}

# ---------------------------------------------------------------------------
# S3 Bucket — stores CodeDeploy deployment revision bundles
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "revisions_bucket" {
  bucket = "devops-pipeline-revisions-${var.suffix}"

  # Prevent accidental deletion of the bucket with objects still in it
  force_destroy = false

  tags = { Name = "devops-pipeline-revisions" }
}

# Enable versioning so you can roll back to any previous deployment bundle
resource "aws_s3_bucket_versioning" "revisions_versioning" {
  bucket = aws_s3_bucket.revisions_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access — deployment bundles should only be accessed
# by the CodeDeploy agent via IAM, never via public URLs.
resource "aws_s3_bucket_public_access_block" "revisions_public_block" {
  bucket = aws_s3_bucket.revisions_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# CodeDeploy — orchestrates application deployments to EC2
# ---------------------------------------------------------------------------

resource "aws_codedeploy_app" "app" {
  name             = "devops-pipeline-app"
  compute_platform = "Server"   # "Server" = EC2/on-prem (vs "Lambda" or "ECS")
}

resource "aws_codedeploy_deployment_group" "app_group" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "devops-pipeline-app-group"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn

  # In-place deployment — updates the app on the SAME EC2 instance.
  # For zero-downtime in production, consider Blue/Green deployments
  # with an Auto Scaling Group and ALB.
  deployment_style {
    deployment_type   = "IN_PLACE"
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
  }

  # Target instances that have this tag — this is how CodeDeploy knows
  # WHICH EC2 instances to deploy to.
  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "devops-pipeline-server"
  }

  # Auto-rollback on deployment failure
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# IAM role for the CodeDeploy SERVICE (not the EC2 instance)
resource "aws_iam_role" "codedeploy_service_role" {
  name = "devops-pipeline-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_service_role_attach" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# ---------------------------------------------------------------------------
# Elastic IP — gives the EC2 instance a STABLE public IP address
# ---------------------------------------------------------------------------
# Without an EIP, the public IP changes every time the instance stops/starts.
# The EIP is referenced in the CD pipeline health check and can be pointed
# to by a DNS A record.

resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id
  tags = {
    Name = "devops-pipeline-eip"
  }
}
