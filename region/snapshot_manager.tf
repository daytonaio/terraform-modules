// Copyright (c) 2025 Daytona
// Licensed under the MIT License - see LICENSE file for details
//
// Snapshot Manager resources: S3 bucket, IAM roles, ECS task definition, security groups, ALB, and ECS service

// S3 Bucket for Snapshot Manager
resource "aws_s3_bucket" "snapshot_manager" {
  count  = local.deploy_snapshot_manager ? 1 : 0
  bucket = "daytona-snapshots-${var.name}-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "daytona-snapshots-${var.name}"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "snapshot_manager" {
  count  = local.deploy_snapshot_manager ? 1 : 0
  bucket = aws_s3_bucket.snapshot_manager[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "snapshot_manager" {
  count  = local.deploy_snapshot_manager ? 1 : 0
  bucket = aws_s3_bucket.snapshot_manager[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// CloudWatch Log Group for Snapshot Manager
resource "aws_cloudwatch_log_group" "snapshot_manager" {
  count             = local.deploy_snapshot_manager ? 1 : 0
  name              = "/ecs/daytona-snapshot-manager-${var.name}"
  retention_in_days = 30

  tags = merge(var.tags, {
    Region = var.name
  })
}

// ECS Task Execution Role for Snapshot Manager
resource "aws_iam_role" "snapshot_manager_ecs_execution" {
  count = local.deploy_snapshot_manager ? 1 : 0
  name  = "daytona-snap-exec-${var.name}"

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

  tags = merge(var.tags, {
    Region = var.name
  })
}

resource "aws_iam_role_policy_attachment" "snapshot_manager_ecs_execution" {
  count      = local.deploy_snapshot_manager ? 1 : 0
  role       = aws_iam_role.snapshot_manager_ecs_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// ECS Task Role for Snapshot Manager
resource "aws_iam_role" "snapshot_manager_ecs_task" {
  count = local.deploy_snapshot_manager ? 1 : 0
  name  = "daytona-snap-task-${var.name}"

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

  tags = merge(var.tags, {
    Region = var.name
  })
}

// S3 Full Access Policy for Snapshot Manager Task Role
resource "aws_iam_role_policy" "snapshot_manager_s3_access" {
  count = local.deploy_snapshot_manager ? 1 : 0
  name  = "s3-full-access"
  role  = aws_iam_role.snapshot_manager_ecs_task[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion"
        ]
        Resource = [
          aws_s3_bucket.snapshot_manager[0].arn,
          "${aws_s3_bucket.snapshot_manager[0].arn}/*"
        ]
      }
    ]
  })
}

// ECS Task Definition for Snapshot Manager
resource "aws_ecs_task_definition" "snapshot_manager" {
  count                    = local.deploy_snapshot_manager ? 1 : 0
  family                   = "daytona-snapshot-manager-${var.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.snapshot_manager_cpu
  memory                   = var.snapshot_manager_memory
  execution_role_arn       = aws_iam_role.snapshot_manager_ecs_execution[0].arn
  task_role_arn            = aws_iam_role.snapshot_manager_ecs_task[0].arn

  container_definitions = jsonencode([{
    name      = "snapshot-manager"
    image     = var.snapshot_manager_image
    essential = true

    portMappings = [{
      containerPort = local.snapshot_manager_container_port
      protocol      = "tcp"
    }]

    environment = [
      // Distribution Registry S3 storage configuration
      {
        name  = "REGISTRY_STORAGE"
        value = "s3"
      },
      {
        name  = "REGISTRY_STORAGE_S3_REGION"
        value = data.aws_region.current.id
      },
      {
        name  = "REGISTRY_STORAGE_S3_BUCKET"
        value = aws_s3_bucket.snapshot_manager[0].id
      },
      {
        name  = "REGISTRY_STORAGE_S3_ENCRYPT"
        value = "true"
      },
      {
        name  = "REGISTRY_STORAGE_S3_SECURE"
        value = "true"
      },
      {
        name  = "REGISTRY_STORAGE_S3_V4AUTH"
        value = "true"
      },
      // Disable storage health check (fails on empty bucket)
      {
        name  = "REGISTRY_HEALTH_STORAGEDRIVER_ENABLED"
        value = "false"
      },
      // Registry HTTP configuration
      {
        name  = "REGISTRY_HTTP_ADDR"
        value = "0.0.0.0:${local.snapshot_manager_container_port}"
      },
      // Enable delete operations
      {
        name  = "REGISTRY_STORAGE_DELETE_ENABLED"
        value = "true"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.snapshot_manager[0].name
        "awslogs-region"        = data.aws_region.current.id
        "awslogs-stream-prefix" = "snapshot-manager"
      }
    }
  }])

  tags = merge(var.tags, {
    Region = var.name
  })
}

// Security Group for Snapshot Manager ALB (internal only)
resource "aws_security_group" "snapshot_manager_alb" {
  count       = local.deploy_snapshot_manager ? 1 : 0
  name        = "daytona-snapshot-alb"
  description = "Security group for Daytona Snapshot Manager ALB (internal)"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected[0].cidr_block]
    description = "HTTPS from VPC"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected[0].cidr_block]
    description = "HTTP from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name   = "daytona-snapshot-manager-alb"
    Region = var.name
  })
}

// Security Group for Snapshot Manager ECS Tasks
resource "aws_security_group" "snapshot_manager_ecs" {
  count       = local.deploy_snapshot_manager ? 1 : 0
  name        = "daytona-snapshot-ecs"
  description = "Security group for Daytona Snapshot Manager ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = local.snapshot_manager_container_port
    to_port         = local.snapshot_manager_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.snapshot_manager_alb[0].id]
    description     = "From ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name   = "daytona-snapshot-manager-ecs"
    Region = var.name
  })
}

// Application Load Balancer for Snapshot Manager (always internal)
resource "aws_lb" "snapshot_manager" {
  count              = local.deploy_snapshot_manager ? 1 : 0
  name               = "daytona-snapshot-manager"
  internal           = true
  load_balancer_type = "application"
  security_groups    = concat([aws_security_group.snapshot_manager_alb[0].id], var.additional_alb_security_group_ids)
  subnets            = var.private_subnet_ids

  tags = merge(var.tags, {
    Name   = "daytona-snapshot-manager"
    Region = var.name
  })
}

// ALB Target Group for Snapshot Manager
resource "aws_lb_target_group" "snapshot_manager" {
  count       = local.deploy_snapshot_manager ? 1 : 0
  name        = "daytona-snapshot-manager"
  port        = local.snapshot_manager_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/v2/"
    port                = "traffic-port"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    Region = var.name
  })
}

// ALB HTTPS Listener for Snapshot Manager
resource "aws_lb_listener" "snapshot_manager_https" {
  count             = local.deploy_snapshot_manager && var.certificate_arn != null ? 1 : 0
  load_balancer_arn = aws_lb.snapshot_manager[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.snapshot_manager[0].arn
  }
}

// ALB HTTP Listener for Snapshot Manager (redirect to HTTPS or forward)
resource "aws_lb_listener" "snapshot_manager_http" {
  count             = local.deploy_snapshot_manager ? 1 : 0
  load_balancer_arn = aws_lb.snapshot_manager[0].arn
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

    target_group_arn = var.certificate_arn == null ? aws_lb_target_group.snapshot_manager[0].arn : null
  }
}

// ECS Service for Snapshot Manager
resource "aws_ecs_service" "snapshot_manager" {
  count           = local.deploy_snapshot_manager ? 1 : 0
  name            = "daytona-snapshot-manager"
  cluster         = aws_ecs_cluster.main[0].id
  task_definition = aws_ecs_task_definition.snapshot_manager[0].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = concat([aws_security_group.snapshot_manager_ecs[0].id], var.additional_snapshot_manager_ecs_security_group_ids)
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.snapshot_manager[0].arn
    container_name   = "snapshot-manager"
    container_port   = local.snapshot_manager_container_port
  }

  depends_on = [aws_lb_listener.snapshot_manager_http]

  tags = merge(var.tags, {
    Region = var.name
  })
}
