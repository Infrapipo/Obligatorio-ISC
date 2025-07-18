resource "kubectl_manifest" "pvc_monitor" {
  yaml_body = file("manifests/storage/pvc-monitor-app.yml")
  depends_on = [ kubectl_manifest.storageclass ]
}

resource "kubectl_manifest" "pvc_web_server" {
  yaml_body = file("manifests/storage/pvc-web-server.yml")
  depends_on = [ kubectl_manifest.storageclass ]
}

resource "kubectl_manifest" "pvc_postgres" {
  yaml_body = file("manifests/storage/pvc-postgres.yml")
  depends_on = [ kubectl_manifest.storageclass ]
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


resource "kubectl_manifest" "storageclass" {
  yaml_body = templatefile("manifests/storage/storage-class.yml", {
    nfs_server_ip = aws_instance.nfs_server.private_ip
  })
  depends_on = [aws_instance.nfs_server]
}
resource "aws_security_group" "nfs_sg" {
  name        = "nfs_sg"
  description = "Security group for NFS server"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups =  [aws_security_group.sg-node-group.id]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description      = "NFS UDP"
    from_port        = 2049
    to_port          = 2049
    protocol         = "udp"
    security_groups  = [ aws_security_group.sg-node-group.id ]
  }
  ingress {
    description      = "RPC portmap TCP"
    from_port        = 111
    to_port          = 111
    protocol         = "tcp"
    security_groups  = [ aws_security_group.sg-node-group.id ]
  }
  ingress {
    description      = "RPC portmap UDP"
    from_port        = 111
    to_port          = 111
    protocol         = "udp"
    security_groups  = [ aws_security_group.sg-node-group.id ]
  }
  ingress {
    description      = "mountd (Amazon Linux default) TCP"
    from_port        = 20048
    to_port          = 20048
    protocol         = "tcp"
    security_groups  = [ aws_security_group.sg-node-group.id ]
  }
  ingress {
    description      = "mountd UDP"
    from_port        = 20048
    to_port          = 20048
    protocol         = "udp"
    security_groups  = [ aws_security_group.sg-node-group.id ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
  }
}

