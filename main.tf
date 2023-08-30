#######################################################################################
### ALB
#######################################################################################
resource "aws_lb" "lb" {
  name               = var.alb_name
  internal           = var.alb_internal
  load_balancer_type = var.alb_balancer_type
  security_groups    = var.alb_security_ids
  subnets            = var.subnets

  tags = {
    Env      = "${var.env}"
    Resource = "lb"
    Name     = "${var.alb_name}"
  }
}

resource "aws_lb_listener" "http" {
  count = var.alb_to_listener_properties.http.is_create ? 1 : 0

  load_balancer_arn = aws_lb.lb.arn
  port              = var.alb_to_listener_properties.http.port
  protocol          = var.alb_to_listener_properties.http.protocol

  // Redirect
  dynamic "default_action" {
    for_each = var.alb_to_listener_properties.http.is_redirect ? [1] : []

    content {
      type             = "redirect"
      target_group_arn = var.alb_to_listener_properties.http.is_target ? aws_lb_target_group.tgs["green"].arn : null

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  // forward
  dynamic "default_action" {
    for_each = var.alb_to_listener_properties.http.is_forward ? [1] : []

    content {
      type             = "forward"
      target_group_arn = var.alb_to_listener_properties.http.is_target ? aws_lb_target_group.tgs["green"].arn : null
    }
  }

  tags = {
    Name     = "${var.alb_name}-http"
    Resource = "http-listener"
    Env      = "${var.env}"
  }
}

resource "aws_lb_listener" "https" {
  count = var.alb_to_listener_properties.https.is_create ? 1 : 0

  load_balancer_arn = aws_lb.lb.arn
  port              = var.alb_to_listener_properties.https.port
  protocol          = var.alb_to_listener_properties.https.protocol
  ssl_policy        = var.alb_to_listener_properties.https.ssl_policy
  certificate_arn   = var.alb_to_listener_properties.https.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = var.alb_to_listener_properties.https.is_target ? aws_lb_target_group.tgs["green"].arn : null
  }

  tags = {
    Name     = "${var.alb_name}-https"
    Resource = "https-listener"
    Env      = "${var.env}"
  }
}

resource "aws_lb_target_group" "tgs" {
  for_each = var.alb_target_groups

  name        = each.value.name
  port        = each.value.port
  protocol    = "HTTP"
  target_type = "ip" // ECS 경우 TargetType이 ip
  vpc_id      = var.vpc_id

  health_check {
    healthy_threshold   = each.value.health.healthy_threshold
    interval            = each.value.health.interval
    protocol            = each.value.health.protocol
    matcher             = each.value.health.matcher
    timeout             = each.value.health.timeout
    path                = each.value.health.path
    unhealthy_threshold = each.value.health.unhealthy_threshold
  }

  tags = {
    Name     = "${each.value.name}"
    Resource = "tg"
    Env      = "${var.env}"
  }
}

#######################################################################################
### ECR
#######################################################################################
resource "aws_ecr_repository" "ecr_repo" {
  name                 = var.ecr_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "ecr_repo_policy" {
  repository = aws_ecr_repository.ecr_repo.name
  policy     = jsonencode(var.ecr_policy_json)
}

# #######################################################################################
# ### ECS Cluster
# #######################################################################################
resource "aws_ecs_cluster" "cluster" {
  name = "${var.ecs_middle_name}-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "cluster_provider" {
  cluster_name       = aws_ecs_cluster.cluster.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = lookup(var.ecs_provider_weights, "fargate")
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = lookup(var.ecs_provider_weights, "fargate_spot")
  }
}

# #######################################################################################
# ### ECS Task
# #######################################################################################
resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${var.ecs_middle_name}-family"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tonumber(var.ecs_task.hard_cpu)
  memory                   = tonumber(var.ecs_task.hard_memory)

  execution_role_arn = var.ecs_task.execution_role_arn
  task_role_arn      = var.ecs_task.task_role_arn
  network_mode       = "awsvpc"

  // Defauilt Container Definition
  container_definitions = jsonencode([
    {
      name      = "${var.ecs_middle_name}-container"
      image     = "zkfmapf123/healthcheck"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [{
        "containerPort" : tonumber("${var.alb_target_groups.green.port}"),
        "hostPort" : tonumber("${var.alb_target_groups.green.port}"),
        "protocol" : "tcp"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.ecs_middle_name}" # CloudWatch 로그 그룹 이름
          "awslogs-create-group"  = "true"
          "awslogs-region"        = "${var.region}" # AWS 리전 이름
          "awslogs-stream-prefix" = "ecs"           # 로그 스트림의 접두사
        }
      },
      environment = [],
      secrets = [
        {
          "name" : "PORT",
          "ValueFrom" : "${aws_secretsmanager_secret.secret_manager.arn}:PORT::"
        }
      ]
    }
  ])

  lifecycle {
    ignore_changes = [
      container_definitions
    ]
  }
}

# #######################################################################################
# ### ECS Service
# #######################################################################################
resource "aws_security_group" "ecs_sg" {
  name        = "${var.ecs_middle_name}-ecs-sg"
  description = "${var.ecs_middle_name}-ecs-sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = tonumber("${var.alb_target_groups.green.port}")
    to_port         = tonumber("${var.alb_target_groups.green.port}")
    protocol        = "tcp"
    security_groups = var.alb_security_ids
  }

  ingress {
    from_port       = tonumber("${var.alb_target_groups.blue.port}")
    to_port         = tonumber("${var.alb_target_groups.blue.port}")
    protocol        = "tcp"
    security_groups = var.alb_security_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Env      = "${var.env}"
    Resource = "sg"
    Name     = "${var.ecs_middle_name}"
  }
}

resource "aws_ecs_service" "service" {
  launch_type            = "FARGATE"
  name                   = "${var.ecs_middle_name}-container"
  cluster                = aws_ecs_cluster.cluster.arn
  task_definition        = aws_ecs_task_definition.task_definition.arn
  desired_count          = var.ecs_desired_count
  enable_execute_command = true // docker exec 허용

  network_configuration {
    assign_public_ip = true
    subnets          = var.subnets
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  force_new_deployment = false

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  // http
  dynamic "load_balancer" {
    for_each = var.alb_to_listener_properties.http.is_create && var.alb_to_listener_properties.http.is_target ? [1] : []

    content {
      target_group_arn = aws_lb_listener.http[0].default_action[0].target_group_arn
      container_name   = "${var.ecs_middle_name}-container"
      container_port   = aws_lb_target_group.tgs["green"].port
    }
  }

  // https
  dynamic "load_balancer" {
    for_each = var.alb_to_listener_properties.https.is_create && var.alb_to_listener_properties.https.is_target ? [1] : []

    content {
      target_group_arn = aws_lb_listener.https[0].default_action[0].target_group_arn
      container_name   = "${var.ecs_middle_name}-container"
      container_port   = aws_lb_target_group.tgs["green"].port
    }
  }

  lifecycle {
    # 서비스를 중단하지 않고, 새로운 서비스가 활성화된 경우에만 폐기된다.
    create_before_destroy = true
    ignore_changes = [
      desired_count,  // 스케일링 처리 될 수 있음
      task_definition // Task Definition이 바뀔수 있음
    ]
  }
}

# #######################################################################################
# ### CodeDeploy
# #######################################################################################
resource "aws_codedeploy_app" "code_deploy" {
  compute_platform = "ECS"
  name             = "${var.ecs_middle_name}-codedeploy"
}

resource "aws_codedeploy_deployment_group" "ecs_code_deploy_group" {
  app_name               = aws_codedeploy_app.code_deploy.name
  deployment_group_name  = "${var.ecs_middle_name}-deploy-group"
  deployment_config_name = var.codedeploy_config_name
  service_role_arn       = var.codedeploy_role_arn

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 1
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.cluster.name
    service_name = aws_ecs_service.service.name
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }


  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [
          var.alb_to_listener_properties.https.is_target ? aws_lb_listener.https[0].arn : aws_lb_listener.http[0].arn
        ]
      }

      ## Blue
      target_group {
        name = lookup(aws_lb_target_group.tgs, "blue").name
      }

      ## Green
      target_group {
        name = lookup(aws_lb_target_group.tgs, "green").name
      }
    }
  }
}

# #######################################################################################
# ### Secret manager
# #######################################################################################
resource "aws_secretsmanager_secret" "secret_manager" {
  name = "${var.ecs_middle_name}-${var.env}-env"

  tags = {
    Name     = "${var.ecs_middle_name}-secret_manager"
    Env      = "${var.env}"
    Resource = "secret-manager"
  }
}

resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id = aws_secretsmanager_secret.secret_manager.id
  secret_string = jsonencode({
    "PORT" : "${var.alb_target_groups.green.port}"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

