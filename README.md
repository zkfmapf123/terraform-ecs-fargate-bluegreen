# ECS Fargate Blue/Green

## Desc

- ECS Fargate Task의 경우 Amazon exec를 사용해서 Container 접근이 가능합니다.
- Secret Manager를 사용하여 Env에 접근합니다.
- CodeDeploy를 사용하여 blue/green 배포를 진행합니다.

## Required

> iam (iam naming은 자유입니다.)

- ecs-task-execution-role

  - ECS 배포 및 실행에 필요한 iam

  ```
    // s3 + kms (optional)
    s3:PutObject
    s3:GetEncryptionConfiguration
    kms:Decrypt

    // cludwatch
    logs:DescribeLogGroups
    logs:DescribeLogStreams
    logs:CreateLogGroup
    logs:CreateLogStream
    logs:PutLogEvents

    // ecr
    ecr:GetAuthorizationToken
    ecr:BatchCheckLayerAvailability
    ecr:GetDownloadUrlForLayer
    ecr:BatchGetImage

    // ecs + system-manager
    ecs:ExecuteCommand
    ssmmessages:CreateControlChannel
    ssmmessages:CreateDataChannel
    ssmmessages:OpenControlChannel
    ssmmessages:OpenDataChannel

    // secret-manager
    "ssm:GetParameters",
    "secretsmanager:GetSecretValue",
    "kms:Decrypt"
  ```

- ecs-deploy-bluegreen-role

  - CodeDeploy에서 배포에 필요한 iam

  ```
    ecs:CreateTaskSet
    ecs:DeleteTaskSet
    ecs:DescribeServices
    ecs:UpdateServicePrimaryTaskSet
    ecs:RegisterTaskDefinition
    ecs:UpdateService
    elasticloadbalancing:DescribeListeners
    elasticloadbalancing:DescribeRules
    elasticloadbalancing:DescribeTargetGroups
    elasticloadbalancing:ModifyListener
    elasticloadbalancing:ModifyRule
    s3:GetObject
    codedeploy:PutLifecycleEventHookExecutionStatus
    iam:PassRole
  ```

## Docker Exec

```sh
aws ecs execute-command
  --region <region>
  --cluster <cluster>
  --task <task-id>
  --container <container-id>
  --command "/bin/sh"
  --interactive
```

## Make Terraform Resources

> ALB

    - [O] alb_lb
    - [O] alb_lb_listener
    - [O] alb_lb_target_group

> ECR

    - [O] aws_ecr_repository
    - [O] aws_ecr_lifecycle_policy

> ECS

    - [O] aws_ecs_cluster
    - [O] aws_ecs_cluster_capacity_providers
    - [O] aws_ecs_task_definition
    - [O] aws_ecs_service
    - [O] aws_appautoscaling_target
    - [O] aws_appautoscaling_policy

> Secret-Manager

    - [O] aws_secretsmanager_secret

> CodeDeploy

    - [O] aws_codedeploy_app
    - [O] aws_codedeploy_deployment_group

## Benchmark use Apache Benchmark

- <a href="https://httpd.apache.org/docs/2.4/programs/ab.html"> apache benchmark </a>

```
  ab -n 50000 -c 100 [DNS_NAME]
```
