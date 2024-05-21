provider "aws" {
  region = "ap-south-1"
}

# VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "example-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "example-igw"
  }
}

# Subnets
resource "aws_subnet" "example_subnet_1" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "example-subnet-1"
  }
}

resource "aws_subnet" "example_subnet_2" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "example-subnet-2"
  }
}

# Route Table
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }

  tags = {
    Name = "example-route-table"
  }
}

# Associate Subnets with Route Table
resource "aws_route_table_association" "example_subnet_1" {
  subnet_id      = aws_subnet.example_subnet_1.id
  route_table_id = aws_route_table.example.id
}

resource "aws_route_table_association" "example_subnet_2" {
  subnet_id      = aws_subnet.example_subnet_2.id
  route_table_id = aws_route_table.example.id
}

# ECS Cluster
resource "aws_ecs_cluster" "example" {
  name = "example-cluster"
}

# IAM Role and Policy for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "example" {
  family                   = "example-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "example-app"
      image     = "node:20"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# Security Group
resource "aws_security_group" "ecs_service" {
  name        = "ecs_service_sg"
  description = "Allow inbound traffic to the ECS service"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Service
resource "aws_ecs_service" "example" {
  name            = "example-service"
  cluster         = aws_ecs_cluster.example.id
  task_definition = aws_ecs_task_definition.example.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.example_subnet_1.id, aws_subnet.example_subnet_2.id]
    security_groups = [aws_security_group.ecs_service.id]
  }

  desired_count = 1
}

# Output ECS Service Name
output "ecs_service_url" {
  value = aws_ecs_service.example.name
}
