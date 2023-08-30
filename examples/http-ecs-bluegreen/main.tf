##################################################################
provider "aws" {
  region = "ap-northeast-2"
}
##################################################################

locals {
  alb_security_ids = ["sg-028ecb8138bbaf03a"]
  alb_subnets      = ["subnet-0811df42d5fb62450", "subnet-0cea0579be35c640f"]
  vpc_id           = "vpc-05a4c8a92c1fd157a"
  iam_arn          = "arn:aws:iam::021206237994:role/mpx-ecs-codeDeploy-role"
  codedeploy_arn   = "arn:aws:iam::021206237994:role/mpx-ecs-bluegreen-role"
}

module "ecs-fargate-bluegreen" {
  source = "../../"

  // common
  env     = "example-env"
  vpc_id  = local.vpc_id
  region  = "ap-northeast-2"
  subnets = local.alb_subnets

  // alb
  alb_name          = "example-alb"
  alb_internal      = false
  alb_balancer_type = "application"
  alb_security_ids  = local.alb_security_ids
  alb_to_listener_properties = {
    http = {
      is_create   = true
      is_target   = true
      is_forward  = true
      is_redirect = false
      port        = 80
      protocol    = "HTTP"
    },
    https = {
      is_create       = false
      is_target       = false
      is_forward      = false
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = null
      certificate_arn = null
    }
  }

  alb_target_groups = {
    "green" = {
      "name" : "example-green-tg",
      "port" : 3000,
      "health" = {
        enabled             = true
        interval            = 30
        path                = "/health"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      }
    },
    "blue" = {
      "name" : "example-blue-tg",
      "port" : 3001,
      "health" = {
        enabled             = true
        interval            = 30
        path                = "/health"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
  }

  // ecr
  ecr_name = "example-cr"
  ecr_policy_json = {
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
    }]
  }

  // ecs
  ecs_middle_name = "example"
  ecs_provider_weights = {
    fargate      = 1
    fargate_spot = 3
  }

  ecs_task = {
    hard_cpu           = "512"
    hard_memory        = "1024"
    execution_role_arn = local.iam_arn
    task_role_arn      = local.iam_arn
  }

  ecs_desired_count = 1

  // codeDeploy
  codedeploy_role_arn    = local.codedeploy_arn
  codedeploy_config_name = "CodeDeployDefault.ECSAllAtOnce"
}

output "v" {
  value = module.ecs-fargate-bluegreen.ecs
}