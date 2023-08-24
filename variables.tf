#######################################################################################
### Common
#######################################################################################
variable "env" {
  default = "common"
}

variable "vpc_id" {}

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
variable "alb_subnets" {
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
      "port" : 3000
    },
    "blue" : {
      "name" : "example-blue-tg",
      "port" : 3001
    }
  }
}