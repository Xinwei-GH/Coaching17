locals {
  prefix = "xinwei"
}

# Create a new VPC named "xinwei"
resource "aws_vpc" "xinwei_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "xinwei"
  }
}

# Create an Internet Gateway (IGW)
resource "aws_internet_gateway" "xinwei_igw" {
  vpc_id = aws_vpc.xinwei_vpc.id

  tags = {
    Name = "xinwei-igw"
  }
}

# Create the First Public Subnet
resource "aws_subnet" "xinwei_public_subnet_1" {
  vpc_id                  = aws_vpc.xinwei_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1a" # Change to your AWS region

  tags = {
    Name = "xinwei-public-subnet-1"
  }
}

# Create the Second Public Subnet
resource "aws_subnet" "xinwei_public_subnet_2" {
  vpc_id                  = aws_vpc.xinwei_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1b" # Change to another AZ in your region

  tags = {
    Name = "xinwei-public-subnet-2"
  }
}

# Create a Route Table for Public Access
resource "aws_route_table" "xinwei_public_rt" {
  vpc_id = aws_vpc.xinwei_vpc.id

  tags = {
    Name = "xinwei-public-route-table"
  }
}

# Create a Route in the Route Table to allow internet access
resource "aws_route" "xinwei_internet_access" {
  route_table_id         = aws_route_table.xinwei_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.xinwei_igw.id
}

# Associate the First Public Subnet with the Route Table
resource "aws_route_table_association" "xinwei_public_assoc_1" {
  subnet_id      = aws_subnet.xinwei_public_subnet_1.id
  route_table_id = aws_route_table.xinwei_public_rt.id
}

# Associate the Second Public Subnet with the Route Table
resource "aws_route_table_association" "xinwei_public_assoc_2" {
  subnet_id      = aws_subnet.xinwei_public_subnet_2.id
  route_table_id = aws_route_table.xinwei_public_rt.id
}

# Fetch AWS Account ID
data "aws_caller_identity" "current" {}

# Fetch AWS Region
data "aws_region" "current" {}

# Create a Security Group for ECS
resource "aws_security_group" "xinwei_ecs_sg" {
  vpc_id = aws_vpc.xinwei_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to public (update for security)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "xinwei-ecs-security-group"
  }
}

# Create an ECR repository
resource "aws_ecr_repository" "ecr" {
  name         = "${local.prefix}-ecr"
  force_delete = true
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Cluster and Fargate Service
  module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.9.0"

  cluster_name = "${local.prefix}-ecs"

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    xinwei-service = {  # Service name (Change if needed)
      cpu    = 512
      memory = 1024
      container_definitions = {
        xinwei-container = {  # Container name (Change if needed)
          essential = true
          image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${local.prefix}-ecr:latest"
          port_mappings = [
            {
              containerPort = 8080
              protocol      = "tcp"
            }
          ]
        }
      }
      assign_public_ip                   = true
      deployment_minimum_healthy_percent = 100
      subnet_ids                   = [aws_subnet.xinwei_public_subnet_1.id, aws_subnet.xinwei_public_subnet_2.id] 
      security_group_ids           = [aws_security_group.xinwei_ecs_sg.id] 
    }
  }
}
