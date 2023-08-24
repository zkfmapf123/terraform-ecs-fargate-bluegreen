#######################################################################################
### ALB
#######################################################################################
resource "aws_lb" "lb" {
  name               = var.alb_name
  internal           = var.alb_internal
  load_balancer_type = var.alb_balancer_type
  security_groups    = var.alb_security_ids
  subnets            = var.alb_subnets

  tags = {
    Env      = "${var.env}"
    Resource = "lb"
    Name     = "${var.alb_name}"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name     = "${var.alb_name}-http"
    Resource = "http-listener"
    Env      = "${var.env}"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.alb_ssl_policy
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tgs["green"].arn
  }

  tags = {
    Name     = "${var.alb_name}-https"
    Resource = "https-listener"
    Env      = "${var.env}"
  }
}

resource "aws_lb_target_group" "tgs" {
  for_each = var.target_groups

  name        = each.value.name
  port        = each.value.port
  protocol    = "HTTP"
  target_type = "ip" // ECS 경우 TargetType이 ip
  vpc_id      = var.vpc_id

  tags = {
    Name     = "${each.value.name}"
    Resource = "tg"
    Env      = "${var.env}"
  }
}