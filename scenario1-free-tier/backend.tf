###############################################################
# backend.tf — Ressources pour le remote state S3
# Scénario 1 : Free Tier
#
# WORKFLOW en 2 étapes :
#   Étape 1 — Premier apply (state local) :
#     terraform apply  → crée le bucket S3 + table DynamoDB
#
#   Étape 2 — Migration vers le remote state :
#     Décommenter le bloc backend dans provider.tf
#     terraform init -migrate-state  → migre le state local vers S3
###############################################################

# ─── Bucket S3 pour stocker le tfstate ─────────────────────

resource "aws_s3_bucket" "terraform_state" {
  # Nom unique : intègre l'account ID pour éviter les collisions globales
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  # prevent_destroy : empêche terraform destroy de supprimer le bucket state
  # (erreur explicite si on essaie, oblige à commenter cette ligne manuellement)
  # lifecycle {
  #  prevent_destroy = true
  #}

  tags = {
    Name    = "${var.project_name}-tfstate"
    Purpose = "Terraform remote state"
  }
}

# Versioning : chaque apply crée une nouvelle version du tfstate
# Permet de revenir à un état précédent en cas de problème
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Chiffrement AES-256 du tfstate au repos
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloquer tout accès public au bucket (le tfstate contient des secrets)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── Table DynamoDB pour le state locking ──────────────────

# Empêche deux `terraform apply` simultanés de corrompre le state
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST" # Pas de capacité provisionnée : gratuit si peu utilisé
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = "${var.project_name}-terraform-locks"
    Purpose = "Terraform state locking"
  }
}
