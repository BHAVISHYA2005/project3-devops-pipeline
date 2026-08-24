# ===========================================================================
#  Terraform Outputs — values printed after `terraform apply`
# ===========================================================================
#  These values are needed to configure GitHub Secrets for the CD pipeline.
#  Copy them from the output and set them in your repo's Settings → Secrets.
# ===========================================================================

output "ec2_public_ip" {
  description = "Elastic IP address of the EC2 instance"
  value       = aws_eip.app_eip.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the EC2 instance (use this for EC2_PUBLIC_DNS secret)"
  value       = aws_eip.app_eip.public_dns
}

output "app_url" {
  description = "Direct URL to the application health endpoint"
  value       = "http://${aws_eip.app_eip.public_ip}:3000/health"
}

output "codedeploy_app_name" {
  description = "CodeDeploy application name"
  value       = aws_codedeploy_app.app.name
}

output "s3_revisions_bucket" {
  description = "S3 bucket for deployment revisions (use this for S3_BUCKET secret)"
  value       = aws_s3_bucket.revisions_bucket.id
}

output "ec2_instance_id" {
  description = "EC2 instance ID (useful for SSM Session Manager access)"
  value       = aws_instance.app_server.id
}
