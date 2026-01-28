// Copyright (c) 2025 Daytona
// Licensed under the MIT License - see LICENSE file for details
//
// Proxy resources: IAM roles, ECS task definition, security groups, ALB, and ECS service

// CloudWatch Log Group
resource "aws_cloudwatch_log_group" "proxy" {
  count             = local.deploy_proxy ? 1 : 0
  name              = "/ecs/daytona-proxy-${var.name}"
  retention_in_days = 30

  tags = var.tags
}

// ECS Task Execution Role
resource "aws_iam_role" "ecs_execution" {
  count = local.deploy_proxy ? 1 : 0
  name  = "daytona-proxy-execution-${var.name}"

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

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  count      = local.deploy_proxy ? 1 : 0
  role       = aws_iam_role.ecs_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// ECS Task Role
resource "aws_iam_role" "ecs_task" {
  count = local.deploy_proxy ? 1 : 0
  name  = "daytona-proxy-task-${var.name}"

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

// Attach additional IAM policies to task role
resource "aws_iam_role_policy_attachment" "ecs_task_additional" {
  for_each   = local.deploy_proxy ? toset(var.additional_task_policy_arns) : toset([])
  role       = aws_iam_role.ecs_task[0].name
  policy_arn = each.value
}

// ECS Task Definition
resource "aws_ecs_task_definition" "proxy" {
  count                    = local.deploy_proxy ? 1 : 0
  family                   = "daytona-proxy-${var.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.proxy_cpu
  memory                   = var.proxy_memory
  execution_role_arn       = aws_iam_role.ecs_execution[0].arn
  task_role_arn            = aws_iam_role.ecs_task[0].arn

  container_definitions = jsonencode([{
    name      = "proxy"
    image     = var.proxy_image
    essential = true

    portMappings = [{
      containerPort = local.proxy_container_port
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "PROXY_API_KEY"
        value = local.proxy_api_key
      },
      {
        name  = "DAYTONA_API_URL"
        value = var.daytona_api_url
      },
      {
        name  = "PROXY_PORT"
        value = tostring(local.proxy_container_port)
      },
      {
        name  = "PROXY_DOMAIN"
        value = local.proxy_domain
      },
      {
        name  = "PROXY_PROTOCOL"
        value = local.proxy_protocol
      },
      {
        name  = "REDIS_HOST",
        value = ""
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.proxy[0].name
        "awslogs-region"        = data.aws_region.current.id
        "awslogs-stream-prefix" = "proxy"
      }
    }
  }])

  tags = var.tags
}

// Security Group for ALB
resource "aws_security_group" "alb" {
  count       = local.deploy_proxy ? 1 : 0
  name        = "daytona-proxy-alb-${var.name}"
  description = "Security group for Daytona proxy ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP (redirect to HTTPS)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "daytona-proxy-alb-${var.name}"
  })
}

// Security Group for ECS Tasks
resource "aws_security_group" "ecs" {
  count       = local.deploy_proxy ? 1 : 0
  name        = "daytona-proxy-ecs-${var.name}"
  description = "Security group for Daytona proxy ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = local.proxy_container_port
    to_port         = local.proxy_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
    description     = "From ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "daytona-proxy-ecs-${var.name}"
  })
}

// Application Load Balancer
resource "aws_lb" "proxy" {
  count              = local.deploy_proxy ? 1 : 0
  name               = "daytona-proxy-${var.name}"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = concat([aws_security_group.alb[0].id], var.additional_alb_security_group_ids)
  subnets            = var.internal ? var.private_subnet_ids : var.public_subnet_ids

  tags = merge(var.tags, {
    Name = "daytona-proxy-${var.name}"
  })
}

// ALB Target Group
resource "aws_lb_target_group" "proxy" {
  count       = local.deploy_proxy ? 1 : 0
  name        = "daytona-proxy-${var.name}"
  port        = local.proxy_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = var.tags
}

// ALB HTTPS Listener
resource "aws_lb_listener" "https" {
  count             = local.deploy_proxy && var.certificate_arn != null ? 1 : 0
  load_balancer_arn = aws_lb.proxy[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy[0].arn
  }
}

// ALB HTTP Listener (redirect to HTTPS or forward)
resource "aws_lb_listener" "http" {
  count             = local.deploy_proxy ? 1 : 0
  load_balancer_arn = aws_lb.proxy[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.certificate_arn != null ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.certificate_arn != null ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.certificate_arn == null ? aws_lb_target_group.proxy[0].arn : null
  }
}

// ECS Service
resource "aws_ecs_service" "proxy" {
  count           = local.deploy_proxy ? 1 : 0
  name            = "daytona-proxy"
  cluster         = aws_ecs_cluster.main[0].id
  task_definition = aws_ecs_task_definition.proxy[0].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = concat([aws_security_group.ecs[0].id], var.additional_ecs_security_group_ids)
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.proxy[0].arn
    container_name   = "proxy"
    container_port   = local.proxy_container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = var.tags
}
