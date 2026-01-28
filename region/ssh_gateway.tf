// Copyright (c) 2025 Daytona
// Licensed under the MIT License - see LICENSE file for details
//
// SSH Gateway resources: IAM roles, ECS task definition, security groups, NLB, and ECS service

// CloudWatch Log Group for SSH Gateway
resource "aws_cloudwatch_log_group" "ssh_gateway" {
  count             = local.deploy_ssh_gateway ? 1 : 0
  name              = "/ecs/daytona-ssh-gateway-${var.name}"
  retention_in_days = 30

  tags = var.tags
}

// ECS Task Execution Role for SSH Gateway
resource "aws_iam_role" "ssh_gateway_ecs_execution" {
  count = local.deploy_ssh_gateway ? 1 : 0
  name  = "daytona-ssh-gateway-execution-${var.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssh_gateway_ecs_execution" {
  count      = local.deploy_ssh_gateway ? 1 : 0
  role       = aws_iam_role.ssh_gateway_ecs_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// ECS Task Role for SSH Gateway
resource "aws_iam_role" "ssh_gateway_ecs_task" {
  count = local.deploy_ssh_gateway ? 1 : 0
  name  = "daytona-ssh-gateway-task-${var.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

// ECS Task Definition for SSH Gateway
resource "aws_ecs_task_definition" "ssh_gateway" {
  count                    = local.deploy_ssh_gateway ? 1 : 0
  family                   = "daytona-ssh-gateway-${var.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ssh_gateway_cpu
  memory                   = var.ssh_gateway_memory
  execution_role_arn       = aws_iam_role.ssh_gateway_ecs_execution[0].arn
  task_role_arn            = aws_iam_role.ssh_gateway_ecs_task[0].arn

  container_definitions = jsonencode([{
    name      = "ssh-gateway"
    image     = var.ssh_gateway_image
    essential = true

    portMappings = [{
      containerPort = local.ssh_gateway_container_port
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "SSH_GATEWAY_API_KEY"
        value = local.ssh_gateway_api_key
      },
      {
        name  = "DAYTONA_API_URL"
        value = var.daytona_api_url
      },
      {
        name  = "SSH_GATEWAY_PORT"
        value = tostring(local.ssh_gateway_container_port)
      },
      {
        name  = "SSH_GATEWAY_DOMAIN"
        value = local.ssh_gateway_domain
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ssh_gateway[0].name
        "awslogs-region"        = data.aws_region.current.id
        "awslogs-stream-prefix" = "ssh-gateway"
      }
    }
  }])

  tags = var.tags
}

// Security Group for NLB
resource "aws_security_group" "nlb" {
  count       = local.deploy_ssh_gateway ? 1 : 0
  name        = "daytona-ssh-gateway-nlb-${var.name}"
  description = "Security group for Daytona SSH Gateway NLB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = local.ssh_gateway_port
    to_port     = local.ssh_gateway_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH Gateway"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "daytona-ssh-gateway-nlb-${var.name}"
  })
}

// Security Group for SSH Gateway ECS Tasks
resource "aws_security_group" "ssh_gateway_ecs" {
  count       = local.deploy_ssh_gateway ? 1 : 0
  name        = "daytona-ssh-gateway-ecs-${var.name}"
  description = "Security group for Daytona SSH Gateway ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = local.ssh_gateway_container_port
    to_port     = local.ssh_gateway_container_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected[0].cidr_block]
    description = "From NLB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "daytona-ssh-gateway-ecs-${var.name}"
  })
}

// Network Load Balancer for SSH Gateway
resource "aws_lb" "ssh_gateway" {
  count              = local.deploy_ssh_gateway ? 1 : 0
  name               = "daytona-ssh-gw-${var.name}"
  internal           = var.internal
  load_balancer_type = "network"
  security_groups    = concat([aws_security_group.nlb[0].id], var.additional_nlb_security_group_ids)
  subnets            = var.internal ? var.private_subnet_ids : var.public_subnet_ids

  tags = merge(var.tags, {
    Name = "daytona-ssh-gateway-${var.name}"
  })
}

// NLB Target Group for SSH Gateway
resource "aws_lb_target_group" "ssh_gateway" {
  count       = local.deploy_ssh_gateway ? 1 : 0
  name        = "daytona-ssh-gw-${var.name}"
  port        = local.ssh_gateway_container_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
    unhealthy_threshold = 2
  }

  tags = var.tags
}

// NLB Listener for SSH Gateway
resource "aws_lb_listener" "ssh_gateway" {
  count             = local.deploy_ssh_gateway ? 1 : 0
  load_balancer_arn = aws_lb.ssh_gateway[0].arn
  port              = local.ssh_gateway_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ssh_gateway[0].arn
  }
}

// ECS Service for SSH Gateway
resource "aws_ecs_service" "ssh_gateway" {
  count           = local.deploy_ssh_gateway ? 1 : 0
  name            = "daytona-ssh-gateway"
  cluster         = aws_ecs_cluster.main[0].id
  task_definition = aws_ecs_task_definition.ssh_gateway[0].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = concat([aws_security_group.ssh_gateway_ecs[0].id], var.additional_ssh_gateway_ecs_security_group_ids)
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ssh_gateway[0].arn
    container_name   = "ssh-gateway"
    container_port   = local.ssh_gateway_container_port
  }

  depends_on = [aws_lb_listener.ssh_gateway]

  tags = var.tags
}
