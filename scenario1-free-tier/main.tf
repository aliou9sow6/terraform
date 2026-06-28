###############################################################
# main.tf — Ressources principales
# Scénario 1 : VPC + EC2 t2.micro + Docker Compose + Elastic IP
###############################################################

# ─── Data Sources ──────────────────────────────────────────

# Account ID AWS courant (utilisé dans backend.tf pour nommer le bucket S3)
data "aws_caller_identity" "current" {}

# ─── VPC ───────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Permet la résolution DNS interne
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ─── Subnet public ─────────────────────────────────────────

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true  # Toutes les EC2 du subnet reçoivent une IP publique

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# ─── Internet Gateway ──────────────────────────────────────

# Passerelle vers Internet pour le VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ─── Table de routage ──────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route par défaut vers Internet via l'IGW
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Association de la route table au subnet public
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ─── Security Group ────────────────────────────────────────

resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg"
  description = "Security Group pour le serveur portfolio"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTP frontend
  ingress {
    description = "HTTP Frontend"
    from_port   = var.app_port_frontend
    to_port     = var.app_port_frontend
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend API
  ingress {
    description = "Backend API"
    from_port   = var.app_port_backend
    to_port     = var.app_port_backend
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (pour les certificats futurs)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tout le trafic sortant autorisé
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ─── Clé SSH ───────────────────────────────────────────────

# Génération automatique d'une clé RSA 4096 bits
resource "tls_private_key" "portfolio" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Enregistrement de la clé publique dans AWS
resource "aws_key_pair" "portfolio" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.portfolio.public_key_openssh

  tags = {
    Name = "${var.project_name}-keypair"
  }
}

# Sauvegarde locale de la clé privée (permissions 400 côté Unix)
resource "local_file" "private_key" {
  content         = tls_private_key.portfolio.private_key_pem
  filename        = "${path.module}/portfolio-keypair.pem"
  file_permission = "0400"
}

# ─── EC2 Instance ──────────────────────────────────────────

resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.portfolio.key_name

  # Volume EBS root (max 30 Go Free Tier)
  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true  # Chiffrement du volume au repos
  }

  # User Data : script exécuté au premier démarrage de l'instance
  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", {
    dockerhub_username  = var.dockerhub_username
    backend_image_tag   = var.backend_image_tag
    frontend_image_tag  = var.frontend_image_tag
    mongo_root_username = var.mongo_root_username
    mongo_root_password = var.mongo_root_password
    backend_port        = var.app_port_backend
    frontend_port       = var.app_port_frontend
    project_name        = var.project_name
  }))

  # Remplacement de l'instance si le user_data change
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-server"
  }
}

# ─── Elastic IP ────────────────────────────────────────────

# IP publique statique (ne change pas au redémarrage)
resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  # S'assurer que l'IGW existe avant l'EIP
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-eip"
  }
}
