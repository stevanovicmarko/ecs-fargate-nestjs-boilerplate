provider "aws" {
  region = var.aws_region
}

# use default VPC
data "aws_vpc" "default" {
  default = true
}

# Use default public subnets
data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Security Group for ALB and ECS
resource "aws_security_group" "sg" {
  name        = var.security_group_name
  description = "Allow traffic to ECS Fargate and ALB"
  vpc_id      = data.aws_vpc.default.id

  # Egress rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #  # Ingress rules
  #  ingress {
  #    from_port   = var.container_port
  #    to_port     = var.container_port
  #    protocol    = "tcp"
  #    cidr_blocks = ["0.0.0.0/0"]
  #  }
  #
  #  ingress {
  #    from_port   = 80
  #    to_port     = 80
  #    protocol    = "tcp"
  #    cidr_blocks = ["0.0.0.0/0"]
  #  }

  dynamic "ingress" {
    for_each = toset([
      {
        from_port = var.container_port,
        to_port   = var.container_port,
      },
      {
        from_port = 80,
        to_port   = 80,
      }
    ])
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }


}

# Application Load Balancer (ALB)
resource "aws_lb" "my_app_load_balancer" {
  name               = var.load_balancer_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = data.aws_subnets.default_public.ids

  enable_deletion_protection = false
}

# Target Group ALB
resource "aws_lb_target_group" "my_target_group" {
  name     = var.target_group_name
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    port                = var.container_port
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/api/healthcheck"
    protocol            = "HTTP"
    matcher             = "200"
  }
  target_type = "ip"
}

# Listener for ALB
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.my_app_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = var.log_group
  retention_in_days = 30
}

# ECS Cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = var.ecs_cluster_name
}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.my_task.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default_public.ids
    assign_public_ip = true
    security_groups  = [aws_security_group.sg.id]
  }

  desired_count = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.my_target_group.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }
}

# ECR Repository for the app
resource "aws_ecr_repository" "my_ecr_repo" {
  name         = var.ecr_repository_name
  force_delete = true
}

resource "aws_iam_role_policy" "ecs_execution_policy" {
  name = "ecs_execution_policy"
  role = aws_iam_role.ecs_execution_role.id

  # Policy to allow ECS to pull images from ECR and write logs to CloudWatch
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}


# IAM Role for ECS Task Execution (allows ECS to pull images from ECR and write logs to CloudWatch)
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
      },
    ],
  })
}

# TODO: Add IAM ECS Task Role (allows task to communicate with other AWS services)

# ECS Task Definition
resource "aws_ecs_task_definition" "my_task" {
  family                   = var.task_definition_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = var.container_name,
      image = "${aws_ecr_repository.my_ecr_repo.repository_url}:latest",
      portMappings = [
        {
          containerPort = var.container_port
        }
      ]
      healthcheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/api/healthcheck || exit 1"]
        interval    = 30
        timeout     = 5
        startPeriod = 60
        retries     = 3
      }
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = var.log_group,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

