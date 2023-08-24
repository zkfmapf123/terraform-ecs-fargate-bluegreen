# ECS Fargate Blue/Green

## Desc

- ECS Fargate Task의 경우 Amazon exec를 사용해서 Container 접근이 가능합니다.
- CodeDeploy를 사용하여 blue/green 배포를 진행합니다.

## Required

> iam

## Make Terraform Resources

> ALB

    - alb_lb
    - alb_lb_listener
    - alb_lb_target_group

> ECR

    - aws_ecr_repository
    - aws_ecr_lifecycle_policy

> ECS

    - aws_ecs_cluster
    - aws_ecs_cluster_capacity_providers
    - aws_ecs_task_definition
    - aws_ecs_service
    - aws_appautoscaling_target
    - aws_appautoscaling_policy

> CodeDeploy

    - aws_codedeploy_app
    - aws_codedeploy_deployment_group
