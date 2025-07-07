resource "kubectl_manifest" "pv_monitor" {
  yaml_body = templatefile("manifests/storage/pv-monitor-ec2.yml", {
    nfs_server_ip = aws_instance.nfs_server.private_ip
  })
  depends_on = [aws_instance.nfs_server]
}
resource "kubectl_manifest" "pv_postgres" {
  yaml_body = templatefile("manifests/storage/pv-postgres-ec2.yml", {
    nfs_server_ip = aws_instance.nfs_server.private_ip
  })
  depends_on = [aws_instance.nfs_server]
}
resource "kubectl_manifest" "pv_web_server" {
  yaml_body = templatefile("manifests/storage/pv-web-server-ec2.yml", {
    nfs_server_ip = aws_instance.nfs_server.private_ip
  })
  depends_on = [aws_instance.nfs_server]
}
resource "kubectl_manifest" "pvc_monitor" {
  yaml_body = file("manifests/storage/pvc-monitor-app.yml")
  depends_on = [ kubectl_manifest.pv_monitor ]
}

resource "kubectl_manifest" "pvc_web_server" {
  yaml_body = file("manifests/storage/pvc-web-server.yml")
  depends_on = [ kubectl_manifest.pv_web_server ]
}

resource "kubectl_manifest" "pvc_postgres" {
  yaml_body = file("manifests/storage/pvc-postgres.yml")
  depends_on = [ kubectl_manifest.pv_postgres ]
}

resource "aws_instance" "nfs_server" {
  ami           = "ami-05ffe3c48a9991133" 
  instance_type = "t3.medium"
  subnet_id     = module.vpc.public_subnets[0]
  vpc_security_group_ids = [ aws_security_group.nfs_sg.id ]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y nfs-utils
              sudo mkdir -p /srv/nfs/kubedata/media
              sudo mkdir -p /srv/nfs/kubedata/db
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
  tags = {
    Name = "nfs-server"
  }
}

resource "aws_security_group" "nfs_sg" {
  name        = "nfs_sg"
  description = "Security group for NFS server"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
  }
}

