variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "suffix" {
  description = "Unique suffix for globally-unique names such as the S3 bucket"
  type        = string
  default     = "xyz123"
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH in. Restrict this to your IP."
  type        = list(string)
  default     = ["0.0.0.0/0"] # open by default so the demo runs out of the box
}
