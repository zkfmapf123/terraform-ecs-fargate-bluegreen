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
variable "alb_name" {}
variable "alb_internal" {
  default = false
}
variable "alb_balancer_type" {
  default = "application"
}
variable "alb_security_ids" {
  type = list(string)
}

variable "alb_ssl_policy" {
  default = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}
variable "alb_certificate_arn" {}

variable "target_groups" {
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
}


#######################################################################################
### ECR
#######################################################################################
variable "ecr_name" {}
variable "ecr_policy_json" {
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
variable "ecs_middle_name" {}
variable "ecs_provider_weights" {
  default = {
    "fargate"      = 1
    "fargate_spot" = 3
  }
}


#######################################################################################
### ECS Task
#######################################################################################
variable "ecs_task" {
  type = map(string)

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
variable "ecs_desired_count" {}

#######################################################################################
### ECS AutoScaling
#######################################################################################

#######################################################################################
### ECS CodeDeploy
#######################################################################################
variable "codedeploy_iam_arn" {}
variable "codedeploy_config" {}