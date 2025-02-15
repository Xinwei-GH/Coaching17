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
  value       = length(aws_iam_role.ecs_task_execution_role) > 0 ? aws_iam_role.ecs_task_execution_role[0].name : data.aws_iam_role.existing_iam_role.name
  description = "IAM Role for ECS Task Execution"
}