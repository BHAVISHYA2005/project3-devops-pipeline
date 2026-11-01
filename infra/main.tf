# ===========================================================================
#  AWS infrastructure for the devops-pipeline-app
# ===========================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # The bucket must exist before `terraform init`. There is no state locking;
  # add a DynamoDB table if more than one person applies at a time.
  backend "s3" {
    bucket = "devops-pipeline-tfstate"
    key    = "devops-pipeline/terraform.tfstate"
    region = "ap-south-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "devops-pipeline"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# ---------------------------------------------------------------------------
# Networking (default VPC — fine for a demo, use a dedicated VPC in production)
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

locals {
  # AWS does not guarantee subnet ordering. Without sort() the instance can
  # silently move to a different AZ between applies.
  subnet_id = sort(data.aws_subnets.default.ids)[0]
}

resource "aws_security_group" "ec2_sg" {
  name        = "devops-pipeline-ec2-sg"
  description = "Allow HTTP, app traffic and SSH for the pipeline instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Application port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "devops-pipeline-ec2-sg" }
}

# ---------------------------------------------------------------------------
# IAM — EC2 uses an instance profile, so no static AWS keys live on the box
# ---------------------------------------------------------------------------

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

resource "aws_iam_role_policy_attachment" "ec2_code_deploy" {
  role       = aws_iam_role.ec2_code_deploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

# Required for `docker pull` from ECR and for `aws ecr get-login-password`.
resource "aws_iam_role_policy_attachment" "ec2_ecr_read" {
  role       = aws_iam_role.ec2_code_deploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "devops-pipeline-instance-profile"
  role = aws_iam_role.ec2_code_deploy_role.name
}

# ---------------------------------------------------------------------------
# ECR — the image registry the pipeline pushes to
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "app" {
  name                 = "devops-pipeline-app"
  image_tag_mutability = "MUTABLE" # immutable would break re-runs of the same commit

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the 10 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ---------------------------------------------------------------------------
# EC2 — runs the CodeDeploy agent and the application container
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

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = templatefile("${path.module}/user-data.sh", {
    region = var.aws_region
  })

  # IMDSv2 only — nothing on this instance needs IMDSv1.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "devops-pipeline-server"
  }
}

# ---------------------------------------------------------------------------
# S3 — stores CodeDeploy revision bundles
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "revisions_bucket" {
  bucket        = "devops-pipeline-revisions-${var.suffix}"
  force_destroy = false

  tags = { Name = "devops-pipeline-revisions" }
}

resource "aws_s3_bucket_versioning" "revisions_versioning" {
  bucket = aws_s3_bucket.revisions_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "revisions_public_block" {
  bucket = aws_s3_bucket.revisions_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# CodeDeploy — in-place deployments to the tagged instance
# ---------------------------------------------------------------------------

resource "aws_codedeploy_app" "app" {
  name             = "devops-pipeline-app"
  compute_platform = "Server"
}

resource "aws_iam_role" "codedeploy_service_role" {
  name = "devops-pipeline-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_service_role_attach" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_codedeploy_deployment_group" "app_group" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "devops-pipeline-app-group"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn

  deployment_style {
    deployment_type   = "IN_PLACE"
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
  }

  # Targets every instance carrying this tag, not a hardcoded instance ID.
  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "devops-pipeline-server"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# ---------------------------------------------------------------------------
# Elastic IP — stable public address for the deploy health check
# ---------------------------------------------------------------------------

resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id

  tags = { Name = "devops-pipeline-eip" }
}
