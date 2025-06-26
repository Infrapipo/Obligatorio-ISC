resource "aws_eks_cluster" "cluster" {
  name     = "obligatorio-isc"
  role_arn = data.aws_iam_role.eks_cluster_role.arn
  version  = "1.33"

  vpc_config {
    subnet_ids             = module.vpc.private_subnets
    endpoint_public_access = true
  }
}
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "obligatorio-isc-workers"
  node_role_arn   = aws_eks_cluster.cluster.role_arn
  subnet_ids      = module.vpc.private_subnets
  launch_template {
    id      = aws_launch_template.lt-node-group.id
    version = "$Latest"
  }
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  depends_on = [ aws_ec2_instance.nfs_server ]
}
 resource "aws_launch_template" "lt-node-group" {
  name_prefix   = "lt-node-group"
  instance_type = "t3.medium"
  network_interfaces {
    associate_public_ip_address = false
    security_groups              = [aws_security_group.sg-node-group.id]
  }
 }
 
 resource "aws_security_group" "sg-node-group" {
  name        = "eks-node-group-sg"
  description = "Security group for EKS node group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
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

resource "null_resource" "apply_ingress_controller" {
  depends_on = [
    aws_eks_node_group.workers,
    aws_eks_cluster.cluster,
  ]

  provisioner "local-exec" {
    command = "kubectl apply -f manifests/ingress-controller.yml"
  }
}

resource "kubectl_manifest" "deployment-django-web" {
  yaml_body = templatefile("manifests/deployments/django-web.yml", {
    DJANGO_APP_IMAGE = docker_registry_image.django_app.name,
    DATABASE_NAME = "obligatorio-isc-DB",
    DATABASE_USER = "postgres",
    DATABASE_PASSWORD = "postgres",
    DATABASE_PORT = "5432",
    DJANGO_SECRET_KEY = "django_secret_key_TEST"
  })
  depends_on = [docker_registry_image.django_app,
  kubectl_manifest.deployment-postgres,
  kubectl_manifest.pvc_web_server,
  aws_eks_node_group.workers]
}
resource "kubectl_manifest" "deployment-postgres" {
  yaml_body = templatefile("manifests/deployments/postgres.yml", {
    DATABASE_NAME = "obligatorio-isc-DB",
    DATABASE_USER = "postgres",
    DATABASE_PASSWORD = "postgres",
    })
  depends_on = [aws_eks_node_group.workers,
  kubectl_manifest.pvc_postgres]
}
resource "kubectl_manifest" "deployment-web-server" {
  yaml_body = templatefile("manifests/deployments/web-server.yml", {
    STATIC_SERVER_IMAGE = docker_registry_image.static_server.name,
  })
  depends_on = [docker_registry_image.static_server,
  kubectl_manifest.pvc_web_server,
  aws_eks_node_group.workers]
}
resource "kubectl_manifest" "deployment-efs-monitor" {
  yaml_body = templatefile("manifests/deployments/efs-monitor-pod.yml", {
    EFS_MONITOR_IMAGE   = docker_registry_image.efs_monitor.name,
    DIRECTORY_TO_WATCH = "/mnt/efs/videos",
  })
  depends_on = [docker_registry_image.efs_monitor,
  kubectl_manifest.pvc_monitor,
  aws_eks_node_group.workers]
}
resource "kubectl_manifest" "django_app_service" {
  yaml_body = file("manifests/services/django-web.yml")
  depends_on = [kubectl_manifest.deployment-django-web]
}
resource "kubectl_manifest" "postgres_service" {
  yaml_body = file("manifests/services/postgres.yml")
  depends_on = [kubectl_manifest.deployment-postgres]
}
resource "kubectl_manifest" "web_server_service" {
  yaml_body = file("manifests/services/web-server.yml")
  depends_on = [kubectl_manifest.deployment-web-server]
}
resource "kubectl_manifest" "ingress" {
  yaml_body  = file("manifests/ingress.yml")
  depends_on = [kubectl_manifest.django_app_service,
  kubectl_manifest.web_server_service,
  kubectl_manifest.postgres_service]
}

