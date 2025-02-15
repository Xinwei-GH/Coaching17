output "subnet_1" {
  value       = aws_subnet.xinwei_public_subnet_1.id
  description = "First Public Subnet ID"
}

output "subnet_2" {
  value       = aws_subnet.xinwei_public_subnet_2.id
  description = "Second Public Subnet ID"
}

output "security_group" {
  value       = aws_security_group.xinwei_ecs_sg.id
  description = "ECS Security Group ID"
}

output "ecs_task_execution_role" {
  value       = try(aws_iam_role.ecs_task_execution_role[0].name, data.aws_iam_role.existing_iam_role.name)
  description = "IAM Role for ECS Task Execution"
}

output "ecs_cluster_name" {
  value       = module.ecs.cluster_name
  description = "ECS Cluster Name"
}

output "ecs_service_name" {
  value       = module.ecs.services["xinwei-service"].name
  description = "ECS Service Name"
}

output "ecs_task_definition" {
  value       = try(module.ecs.services["xinwei-service"].task_definition_arn, "")
  description = "ECS Task Definition ARN"
}

output "ecr_repository_url" {
  value       = try(aws_ecr_repository.ecr[0].repository_url, data.aws_ecr_repository.existing_ecr.repository_url)
  description = "ECR Repository URL"
}

output "vpc_id" {
  value       = aws_vpc.xinwei_vpc.id
  description = "VPC ID"
}

output "region" {
  value       = var.aws_region
  description = "AWS Deployment Region"
}