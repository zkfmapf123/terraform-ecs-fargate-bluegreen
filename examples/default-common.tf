provider "aws" {
  region = "ap-northeast-2"
}

locals {
  alb_security_ids    = ["sg-028ecb8138bbaf03a"]
  alb_subnets         = ["subnet-0811df42d5fb62450", "subnet-0cea0579be35c640f"]
  alb_certificate_arn = "arn:aws:acm:ap-northeast-2:021206237994:certificate/bc05a9e6-cbdc-4b4c-834f-fc42632a487f"
  vpc_id              = "vpc-05a4c8a92c1fd157a"
}

module "default-common" {

  source = "../"

  // common
  env    = "example-env"
  vpc_id = local.vpc_id

  // alb
  alb_name            = "example-alb"
  alb_internal        = false
  alb_balancer_type   = "application"
  alb_security_ids    = local.alb_security_ids
  alb_subnets         = local.alb_subnets
  alb_ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  alb_certificate_arn = local.alb_certificate_arn
  target_groups = {
    "green" = {
      "name" : "example-green-tg",
      "port" : 3000
    },
    "blue" = {
      "name" : "example-blue-tg",
      "port" : 3001
    }
  }


}