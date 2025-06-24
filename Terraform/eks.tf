resource "aws_eks_cluster" "cluster" {
  name     = "obligatorio-isc"
  role_arn = data.aws_iam_role.eks_cluster_role.arn
  version  = "1.33"

  vpc_config {
    subnet_ids             = module.vpc.private_subnets
    endpoint_public_access = true
  }
}
resource "aws_eks_addon" "efs-csi-driver" {
  cluster_name             = aws_eks_cluster.cluster.name
  addon_name               = "aws-efs-csi-driver"
  service_account_role_arn = data.aws_iam_role.eks_cluster_role.arn
}
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "obligatorio-isc-workers"
  node_role_arn   = aws_eks_cluster.cluster.role_arn
  subnet_ids      = module.vpc.private_subnets

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}
resource "aws_ecr_repository" "respository-ecr" {
  name                 = "obligatorio-isc-repository"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}
resource "docker_image" "efs_monitor" {
  name = "${aws_ecr_repository.respository-ecr.repository_url}:efs_monitor-v1"
  build {
    context    = "../efs_monitor"
    dockerfile = "../efs_monitor/dockerfile"
  }
}
resource "docker_image" "static_server" {
  name = "${aws_ecr_repository.respository-ecr.repository_url}:static_server-v1"
  build {
    context    = "../web_srv_image"
    dockerfile = "../web_srv_image/dockerfile"
  }
}
resource "docker_image" "django_app" {
  name = "${aws_ecr_repository.respository-ecr.repository_url}:django-app-v2"
  build {
    context    = "../app"
    dockerfile = "../app/dockerfile"
  }
}
resource "docker_registry_image" "efs_monitor" {
  name       = docker_image.efs_monitor.name
  depends_on = [aws_ecr_repository.respository-ecr]
}
resource "docker_registry_image" "static_server" {
  name       = docker_image.static_server.name
  depends_on = [aws_ecr_repository.respository-ecr]
}
resource "docker_registry_image" "django_app" {
  name       = docker_image.django_app.name
  depends_on = [aws_ecr_repository.respository-ecr]
}
# resource "kubectl_manifest" "ingress_controller1" {
#   provider  = kubectl
#   yaml_body = file("manifests/ingress-controller-services.yml")
#   depends_on = [aws_eks_addon.efs-csi-driver,
#     aws_eks_node_group.workers,
#   aws_eks_cluster.cluster]
# }
# resource "kubectl_manifest" "ingress_controller2" {
#   provider  = kubectl
#   yaml_body = file("manifests/ingress-controller-deploy.yml")
#   depends_on = [aws_eks_addon.efs-csi-driver,
#     aws_eks_node_group.workers,
#     aws_eks_cluster.cluster,
#   kubectl_manifest.ingress_controller1]
# }
resource "null_resource" "wait_for_nodes" {
  depends_on = [
    aws_eks_node_group.workers,
    aws_eks_addon.efs-csi-driver
  ]

  provisioner "local-exec" {
    command = <<EOT
    echo "Esperando a que los nodos estén listos..."
    aws eks --region us-east-1 update-kubeconfig --name obligatorio-isc
    for i in {1..30}; do
      
      READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready')
      if [ "$READY_NODES" -ge 1 ]; then
        echo "Nodos listos: $READY_NODES"
        exit 0
      fi
      echo "Esperando nodos... intento $i"
      sleep 10
    done
    echo "Tiempo de espera agotado, nodos no disponibles"
    exit 1
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
resource "null_resource" "apply_ingress_controller" {
  depends_on = [
    aws_eks_addon.efs-csi-driver,
    aws_eks_node_group.workers,
    aws_eks_cluster.cluster,
    null_resource.wait_for_nodes
  ]

  provisioner "local-exec" {
    command = "kubectl apply --validate=false -f manifests/ingress-controller.yml"
  }
}

resource "kubectl_manifest" "deployment" {
  provider = kubectl
  yaml_body = templatefile("manifests/deployments.yml", {
    EFS_MONITOR_IMAGE   = docker_image.efs_monitor.name,
    STATIC_SERVER_IMAGE = docker_image.static_server.name,
    DJANGO_APP_IMAGE    = docker_image.django_app.name
  })
  depends_on = [
    docker_registry_image.efs_monitor,
    docker_registry_image.static_server,
  docker_registry_image.django_app]
}
resource "kubectl_manifest" "services" {
  provider  = kubectl
  yaml_body = file("manifests/services.yml")
  depends_on = [kubectl_manifest.deployment,
  ]
}
resource "kubectl_manifest" "ingress" {
  provider   = kubectl
  yaml_body  = file("manifests/ingress.yml")
  depends_on = [kubectl_manifest.services]
}
resource "kubectl_manifest" "volume" {
  provider  = kubectl
  yaml_body = file("manifests/volume.yml")
  depends_on = [
    aws_eks_addon.efs-csi-driver,
    aws_eks_node_group.workers
  ]
}