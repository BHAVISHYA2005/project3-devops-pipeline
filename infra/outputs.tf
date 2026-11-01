output "ec2_public_ip" {
  description = "Elastic IP of the EC2 instance"
  value       = aws_eip.app_eip.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name (use as the EC2_PUBLIC_DNS secret)"
  value       = aws_eip.app_eip.public_dns
}

output "app_url" {
  description = "Health endpoint of the deployed app"
  value       = "http://${aws_eip.app_eip.public_ip}:3000/health"
}

output "ecr_repository_url" {
  description = "ECR repository the pipeline pushes images to"
  value       = aws_ecr_repository.app.repository_url
}

output "codedeploy_app_name" {
  description = "CodeDeploy application name"
  value       = aws_codedeploy_app.app.name
}

output "s3_revisions_bucket" {
  description = "Bucket for deployment revisions (use as the S3_BUCKET secret)"
  value       = aws_s3_bucket.revisions_bucket.id
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app_server.id
}
