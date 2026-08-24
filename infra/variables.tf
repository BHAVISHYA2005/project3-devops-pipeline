# ===========================================================================
#  Terraform Variables — configurable inputs for the infrastructure
# ===========================================================================
#  Override these values via:
#    - CLI:           terraform apply -var="suffix=abc123"
#    - File:          terraform.tfvars
#    - Environment:   TF_VAR_suffix=abc123
# ===========================================================================

variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type — t3.micro is free-tier eligible"
  type        = string
  default     = "t3.micro"
}

variable "environment" {
  description = "Deployment environment label (used in tags and app config)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "suffix" {
  description = "Unique suffix for globally-unique resource names like S3 buckets (e.g. your initials + random number)"
  type        = string
  default     = "xyz123"
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH into the EC2 instance. Restrict to your IP in production!"
  type        = list(string)
  default     = ["0.0.0.0/0"]   # WARNING: open to the world — override in prod!
}
