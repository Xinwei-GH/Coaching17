# Fetch AWS Account ID
data "aws_caller_identity" "current" {}

# Fetch AWS Region
data "aws_region" "current" {}

locals {
  prefix = "xinwei"
}

# Fetch existing ECR repository (if it exists)
data "aws_ecr_repository" "existing_ecr" {
  name = "${local.prefix}-ecr"
}

# Create an ECR repository if it doesn't exist
resource "aws_ecr_repository" "ecr" {
  count = length(data.aws_ecr_repository.existing_ecr.id) > 0 ? 0 : 1

  name         = "${local.prefix}-ecr"
  force_delete = true

  lifecycle {
    prevent_destroy = true  # Prevent accidental deletion
    ignore_changes  = [name]  # Ignore name changes to prevent conflicts
  }
}

# Fetch existing IAM Role (if it exists)
data "aws_iam_role" "existing_iam_role" {
  name = "ecsTaskExecutionRole"
}

# Create IAM Role only if it does not exist
resource "aws_iam_role" "ecs_task_execution_role" {
  count = length(data.aws_iam_role.existing_iam_role.name) > 0 ? 0 : 1

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

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_attach" {
  count = length(data.aws_iam_role.existing_iam_role.name) > 0 ? 0 : 1

  role       = aws_iam_role.ecs_task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create a new VPC
resource "aws_vpc" "xinwei_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.prefix}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "xinwei_igw" {
  vpc_id = aws_vpc.xinwei_vpc.id

  tags = {
    Name = "${local.prefix}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "xinwei_public_subnet_1" {
  vpc_id                  = aws_vpc.xinwei_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "${local.prefix}-public-subnet-1"
  }
}

resource "aws_subnet" "xinwei_public_subnet_2" {
  vpc_id                  = aws_vpc.xinwei_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}b"

  tags = {
    Name = "${local.prefix}-public-subnet-2"
  }
}

# Route Table and Association
resource "aws_route_table" "xinwei_public_rt" {
  vpc_id = aws_vpc.xinwei_vpc.id

  tags = {
    Name = "${local.prefix}-public-route-table"
  }
}

resource "aws_route" "xinwei_internet_access" {
  route_table_id         = aws_route_table.xinwei_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.xinwei_igw.id
}

resource "aws_route_table_association" "xinwei_public_assoc_1" {
  subnet_id      = aws_subnet.xinwei_public_subnet_1.id
  route_table_id = aws_route_table.xinwei_public_rt.id
}

resource "aws_route_table_association" "xinwei_public_assoc_2" {
  subnet_id      = aws_subnet.xinwei_public_subnet_2.id
  route_table_id = aws_route_table.xinwei_public_rt.id
}

# Security Group for ECS
resource "aws_security_group" "xinwei_ecs_sg" {
  vpc_id = aws_vpc.xinwei_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.prefix}-ecs-sg"
  }
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
    xinwei-service = {
      cpu    = 512
      memory = 1024
      container_definitions = {
        xinwei-container = {
          essential = true
          image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.prefix}-ecr:latest"
          port_mappings = [
            {
              containerPort = 8080
              protocol      = "tcp"
            }
          ]
        }
      }
      assign_public_ip              = true
      deployment_minimum_healthy_percent = 100
      subnet_ids                    = [aws_subnet.xinwei_public_subnet_1.id, aws_subnet.xinwei_public_subnet_2.id]
      security_group_ids             = [aws_security_group.xinwei_ecs_sg.id]
    }
  }
}