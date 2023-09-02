#######################################################################################
### Common
#######################################################################################
variable "env" {
  default = "common"
}

variable "vpc_id" {}
variable "region" {}
variable "subnets" {
  type = list(string)
}

#######################################################################################
### ALB
#######################################################################################
variable "alb_name" {
  type        = string
  description = "alb 이름"
}
variable "alb_internal" {
  type        = bool
  description = "alb의 제공 공간 여부"
  default     = false
}
variable "alb_balancer_type" {
  default = "application"

  validation {
    condition     = contains(["application", "network"], var.alb_balancer_type)
    error_message = "must be application, network"
  }
}
variable "alb_security_ids" {
  description = "alb에 사용되는 security group들"
  type        = list(string)
}

variable "alb_to_listener_properties" {
  description = "target group의 리스너"

  default = {
    http = {
      is_create   = true
      is_target   = false
      is_forward  = false
      is_redirect = true
      port        = 80
      protocol    = "HTTP"
    },
    https = {
      is_create       = true
      is_target       = true
      is_forward      = true
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      certificate_arn = ""
    }
  }

  validation {
    condition = (
      var.alb_to_listener_properties.http.is_target != var.alb_to_listener_properties.https.is_target
    )
    error_message = "Either is_target should be true, but not both or neither."
  }

  validation {
    condition = (
      var.alb_to_listener_properties.http.is_forward != var.alb_to_listener_properties.https.is_forward
    )
    error_message = "Either is_forward should be true, but not both or neither."
  }
}

variable "alb_target_groups" {
  default = {
    "green" : {
      "name" : "example-green-tg",
      "port" : 3000,
      "health" : {
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
    "blue" : {
      "name" : "example-blue-tg",
      "port" : 3001,
      "health" : {
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

  validation {
    condition     = length(var.alb_target_groups) == 2
    error_message = "target_group is only 2"
  }
}

#######################################################################################
### ECR
#######################################################################################
variable "ecr_name" {
  type        = string
  description = "ECR Repository 이름"
}
variable "ecr_policy_json" {
  description = "ECR Rule"
  default = {
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
}

#######################################################################################
### ECS Cluster
#######################################################################################
variable "ecs_middle_name" {
  type        = string
  description = "ECS에 사용될 전체적인 이름"

}
variable "ecs_provider_weights" {
  type = object({
    fargate      = number
    fargate_spot = number
  })

  default = {
    "fargate"      = 1
    "fargate_spot" = 3
  }
}

variable "is_ecs_container_insight" {
  type        = bool
  description = "container insight"
  default     = false
}


#######################################################################################
### ECS Task
#######################################################################################
variable "ecs_task" {

  type = object({
    hard_cpu           = string
    hard_memory        = string
    execution_role_arn = string
    task_role_arn      = string
  })

  default = {
    hard_cpu           = "512"
    hard_memory        = "1024"
    execution_role_arn = ""
    task_role_arn      = ""
  }
}

#######################################################################################
### ECS Service
#######################################################################################
variable "ecs_desired_count" {
  description = "ecs에서 기본적으로 생성될 Task 개수"
  type        = number

  validation {
    condition     = var.ecs_desired_count > 0
    error_message = "ecs_desired_count is up to 0"
  }
}

#######################################################################################
### ECS CodeDeploy
#######################################################################################
variable "codedeploy_config_name" {
  type    = string
  default = "CodeDeployDefault.ECSAllAtOnce"

  validation {
    condition     = contains(["CodeDeployDefault.ECSAllAtOnce", "CodeDeployDefault.ECSLinear10PercentEvery1Minutes", "CodeDeployDefault.ECSLinear10PercentEvery3Minutes", "CodeDeployDefault.ECSCanary10Percent5Minutes", "CodeDeployDefault.ECSCanary10Percent15Minutes"], var.codedeploy_config_name)
    error_message = "codedeploy config name is must be CodeDeployDefault.ECSAllAtOnce, CodeDeployDefault.ECSLinear10PercentEvery1Minutes , CodeDeployDefault.ECSLinear10PercentEvery3Minutes, CodeDeployDefault.ECSCanary10Percent5Minutes, CodeDeployDefault.ECSCanary10Percent15Minutes"
  }
}

variable "codedeploy_role_arn" {
  type = string
}