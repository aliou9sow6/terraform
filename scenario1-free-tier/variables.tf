###############################################################
# variables.tf — Déclaration de toutes les variables
# Scénario 1 : Free Tier
###############################################################

# ─── Région & projet ───────────────────────────────────────

variable "aws_region" {
  description = "Région AWS cible"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nom du projet (utilisé dans les noms de ressources et les tags)"
  type        = string
  default     = "anoors-portfolio"
}

variable "environment" {
  description = "Environnement cible : dev | staging | prod"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être dev, staging ou prod."
  }
}

# ─── Réseau ────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Bloc CIDR du subnet public"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Zone de disponibilité pour le subnet"
  type        = string
  default     = "us-east-1a"
}

# ─── EC2 ───────────────────────────────────────────────────

variable "instance_type" {
  description = "Type d'instance EC2 (t2.micro éligible Free Tier)"
  type        = string
  default     = "t2.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Utiliser t2.micro ou t3.micro pour rester dans le Free Tier."
  }
}

variable "key_pair_name" {
  description = "Nom de la paire de clés SSH existante dans AWS"
  type        = string
  # Pas de default : obligatoire, à définir dans terraform.tfvars
}

variable "ami_id" {
  description = "AMI Ubuntu 22.04 LTS (us-east-1). Vérifier la dernière version sur AWS."
  type        = string
  default     = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS - us-east-1
}

variable "root_volume_size" {
  description = "Taille du volume root en Go (max 30 Go Free Tier)"
  type        = number
  default     = 20
}

# ─── Application ───────────────────────────────────────────

variable "dockerhub_username" {
  description = "Nom d'utilisateur Docker Hub"
  type        = string
  default     = "anoor9s6"
}

variable "backend_image_tag" {
  description = "Tag de l'image Docker backend"
  type        = string
  default     = "latest"
}

variable "frontend_image_tag" {
  description = "Tag de l'image Docker frontend"
  type        = string
  default     = "latest"
}

variable "mongo_root_username" {
  description = "Nom d'utilisateur admin MongoDB"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "mongo_root_password" {
  description = "Mot de passe admin MongoDB"
  type        = string
  sensitive   = true
  # Obligatoire : définir dans terraform.tfvars (ne pas committer)
}

# ─── Sécurité ──────────────────────────────────────────────

variable "allowed_ssh_cidr" {
  description = "CIDR autorisé pour SSH (restreindre à votre IP)"
  type        = string
  default     = "0.0.0.0/0" # À restreindre en production !
}

variable "app_port_frontend" {
  description = "Port HTTP du frontend"
  type        = number
  default     = 80
}

variable "app_port_backend" {
  description = "Port HTTP du backend"
  type        = number
  default     = 5000
}
