##################################################################
provider "aws" {
  region = "ap-northeast-2"
}
##################################################################

locals {
  alb_subnets    = ["subnet-075c28321b3576d75", "subnet-04f6d2818b1c4120f"]
  vpc_id         = "vpc-0e26eb01bc7d8a3d0"
  iam_arn        = "arn:aws:iam::021206237994:role/mpx-ecs-codeDeploy-role"
  codedeploy_arn = "arn:aws:iam::021206237994:role/mpx-ecs-bluegreen-role"
}

##################################################################
### IAM
##################################################################
resource "aws_iam_role" "ecs" {
  name = "ecs-deploy-role"

  assume_role_policy = jsonencode({
    "Version" : "2008-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "ecs-deploy-role"
  }
}

resource "aws_iam_policy" "s3_kms_group" {
  name = "s3_kms_group"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetEncryptionConfiguration",
          "kms:Decrypt"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "cloudwatch-group" {
  name = "deploy-cloudwatch-group"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "get_ecr_list" {
  name = "deploy-ecr"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "secret_manager" {
  name = "secret_manager"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt",
          "ecs:ExecuteCommand",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource" : [
          "arn:aws:ssm:*",
          "arn:aws:secretsmanager:*",
          "arn:aws:kms:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_group_attachment" {
  for_each = {
    for i, v in [aws_iam_policy.cloudwatch-group, aws_iam_policy.get_ecr_list, aws_iam_policy.secret_manager] :
    i => v
  }

  policy_arn = each.value.arn
  role       = aws_iam_role.ecs.name
}

#############################################################
### CodeDeploy
#############################################################
resource "aws_iam_role" "codedeploy" {
  name = "codeDeploy-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "codedeploy.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "codedeploy_policy" {
  name = "codeDeploy-policy"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:CreateTaskSet",
          "ecs:DeleteTaskSet",
          "ecs:DescribeServices",
          "ecs:UpdateServicePrimaryTaskSet",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "s3:GetObject",
          "codedeploy:PutLifecycleEventHookExecutionStatus",
          "iam:PassRole"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_attachment" {
  policy_arn = aws_iam_policy.codedeploy_policy.arn
  role       = aws_iam_role.codedeploy.name
}


##################################################################
### ALB-SG
##################################################################
resource "aws_security_group" "alb_sg" {
  name        = "ecs-example-alb-sg"
  description = "alb_sg"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "ecs-alb-sg"
    Resource = "sg"
  }
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
  alb_security_ids  = [aws_security_group.alb_sg.id]
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
    execution_role_arn = aws_iam_role.ecs.arn
    task_role_arn      = aws_iam_role.ecs.arn
  }

  is_ecs_container_insight = true
  ecs_desired_count        = 1

  // codeDeploy
  codedeploy_role_arn    = aws_iam_role.codedeploy.arn
  codedeploy_config_name = "CodeDeployDefault.ECSAllAtOnce"
}

output "v" {
  value = module.ecs-fargate-bluegreen.ecs
}