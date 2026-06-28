###############################################################
# provider.tf — Configuration du provider AWS
# Scénario 1 : Free Tier (1 EC2 t2.micro + Docker Compose)
###############################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Provider TLS : génération de la clé SSH RSA
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # Provider local : écriture de la clé privée sur disque
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }

  # Backend S3 pour stocker le state à distance
  # Décommenter après avoir créé le bucket S3 et la table DynamoDB
  # (exécuter d'abord terraform apply sans ce bloc, puis terraform init -migrate-state)
  # backend "s3" {
  #   bucket         = "portfolio-terraform-state-<votre-account-id>"
  #   key            = "scenario1/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "anoors-portfolio-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  # Tags appliqués à toutes les ressources créées par ce provider
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Scenario    = "free-tier"
    }
  }
}
