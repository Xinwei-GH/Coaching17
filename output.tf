#output for Github Action
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

output "ecs_task_definition" {
  value       = module.ecs.services["xinwei-service"].task_definition_arn
  description = "ECS Task Definition ARN"
}