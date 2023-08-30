output "ecs" {
  description = "cluster_name : 클러스터 이름\nservice_name : 서비스 이름\necs_sg_id : ecs에 사용되는 security_group_id\n"

  value = {
    cluster_name = aws_ecs_cluster.cluster.name
    service_name = aws_ecs_service.service.name
    ecs_sg_id    = aws_security_group.ecs_sg.id
  }
}