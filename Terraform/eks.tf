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

resource "kubectl_manifest" "apply_ingress_controller" {

  yaml_body = file("manifests/ingress-controller.yml")

  depends_on = [
    aws_eks_node_group.workers,
    aws_eks_cluster.cluster,
  ]
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
  kubectl_manifest.pvc_web_server]
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
  kubectl_manifest.pvc_web_server,]
}
resource "kubectl_manifest" "deployment-efs-monitor" {
  yaml_body = templatefile("manifests/deployments/efs-monitor-pod.yml", {
    EFS_MONITOR_IMAGE   = docker_registry_image.efs_monitor.name,
    DIRECTORY_TO_WATCH = "/mnt/efs/videos",
  })
  depends_on = [docker_registry_image.efs_monitor,
  kubectl_manifest.pvc_monitor,
]
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

resource "kubectl_manifest" "pvc_monitor" {
  yaml_body = file("manifests/storage/pvc-monitor-app.yml")
  depends_on = [kubectl_manifest.pv_monitor]
}

resource "kubectl_manifest" "pvc_web_server" {
  yaml_body = file("manifests/storage/pvc-web-server.yml")
  depends_on = [kubectl_manifest.pv_web]
}

resource "kubectl_manifest" "pvc_postgres" {
  yaml_body = file("manifests/storage/pvc-postgres.yml")
  depends_on = [kubectl_manifest.pv_postgres]
}


resource "aws_instance" "nfs_server" {
  ami           = "ami-05ffe3c48a9991133" # Amazon Linux 2, región us-east-1
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public_subnets[0]
  vpc_security_group_ids = [ aws_security_group.nfs_sg.id ]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y nfs-utils
              sudo mkdir -p /srv/nfs/kubedata/{static,db,monitor}
              sudo chown -R 1000:1000 /srv/nfs/kubedata/*


              # Crea el directorio a exportar
              sudo mkdir -p /srv/nfs/kubedata
              sudo chown nobody:nogroup /srv/nfs/kubedata
              sudo chmod 777 /srv/nfs/kubedata

              # Configura export
              echo "/srv/nfs/kubedata *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee /etc/exports

              # Arranca el servicio NFS
              sudo systemctl enable --now nfs-server
              sudo exportfs -a

              # Verifica exportaciones
              sudo exportfs -v

              EOF

}

data "template_file" "pv_web" {
  template = file("manifests/storage/pv-web-server-ec2.yml")
  vars = {
    nfs_server_ip = aws_instance.nfs_server.private_ip
  }
}

resource "kubectl_manifest" "pv_web" {
  yaml_body = data.template_file.pv_web.rendered
}

data "template_file" "pv_monitor" {
  template = file("manifests/storage/pv-monitor-ec2.yml")
  vars = {
    nfs_server_ip = aws_instance.nfs_server.private_ip
  }
}
resource "kubectl_manifest" "pv_monitor" {
  yaml_body = data.template_file.pv_monitor.rendered
}
data "template_file" "pv_postgres" {
  template = file("manifests/storage/pv-postgres-ec2.yml")
  vars = {
    nfs_server_ip = aws_instance.nfs_server.private_ip
  }
}
resource "kubectl_manifest" "pv_postgres" {
  yaml_body = data.template_file.pv_postgres.rendered
}
resource "aws_security_group" "nfs_sg" {
  name        = "nfs_sg"
  description = "Security group for NFS server"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
  }
}