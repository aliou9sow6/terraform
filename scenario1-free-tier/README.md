# Scénario 1 — Déploiement Free Tier AWS

Infrastructure complète pour déployer le portfolio sur une EC2 t2.micro avec Docker Compose.
100% éligible AWS Free Tier (12 premiers mois).

---

## Architecture

```
                         Internet
                            │
                     ┌──────▼──────┐
                     │ Elastic IP  │  IP statique publique
                     └──────┬──────┘
                            │
                     ┌──────▼──────┐
                     │  Security   │  :22  SSH
                     │   Group     │  :80  Frontend
                     │             │  :443 HTTPS (futur)
                     │             │  :5000 Backend API
                     └──────┬──────┘
                            │
              ┌─────────────▼─────────────┐
              │     EC2 t2.micro           │
              │     Ubuntu 22.04 LTS       │
              │     20 Go EBS chiffré      │
              │                            │
              │  ┌─────────────────────┐   │
              │  │  Docker Compose     │   │
              │  │                     │   │
              │  │  ┌───────────────┐  │   │
              │  │  │ Nginx:React   │:80│  │
              │  │  └───────────────┘  │   │
              │  │  ┌───────────────┐  │   │
              │  │  │ Node.js/Expr  │:5000│ │
              │  │  └───────────────┘  │   │
              │  │  ┌───────────────┐  │   │
              │  │  │   MongoDB     │  │   │
              │  │  │  (interne)    │  │   │
              │  │  └───────────────┘  │   │
              │  └─────────────────────┘   │
              └────────────────────────────┘
                            │
              ┌─────────────▼─────────────┐
              │  VPC  10.0.0.0/16          │
              │  Subnet public             │
              │  10.0.1.0/24 — us-east-1a  │
              │  Internet Gateway          │
              └────────────────────────────┘
```

---

## Prérequis

```bash
# 1. Terraform >= 1.6
terraform -version

# 2. AWS CLI v2 configuré
aws configure
# Renseigner : Access Key, Secret Key, région (us-east-1), format (json)

# 3. Vérifier l'accès AWS
aws sts get-caller-identity
```

---

## Étapes de déploiement

### Étape 0 — Personnaliser les variables

Éditer `terraform.tfvars` :

```hcl
# Changer le mot de passe MongoDB
mongo_root_password = "MonMotDePasse_Solide_2024!"

# Restreindre SSH à votre IP (recommandé)
allowed_ssh_cidr = "x.x.x.x/32"   # votre IP publique

# Vérifier le nom de la paire de clés
key_pair_name = "portfolio-keypair"
```

> Trouver votre IP : `curl https://ifconfig.me`

---

### Étape 1 — Initialiser Terraform

```bash
cd terraform/scenario1-free-tier

terraform init
```

Terraform télécharge les providers AWS, TLS et Local.

---

### Étape 2 — Valider et planifier

```bash
# Valider la syntaxe
terraform validate

# Voir ce qui sera créé (dry-run, rien de créé)
terraform plan -var-file="terraform.tfvars"
```

Plan attendu : **+12 ressources** à créer, 0 à modifier, 0 à détruire.

---

### Étape 3 — Appliquer (créer l'infrastructure)

```bash
terraform apply -var-file="terraform.tfvars"
# Taper "yes" pour confirmer
```

Durée : **~2 minutes**. À la fin, les outputs s'affichent :

```
elastic_ip       = "54.x.x.x"
frontend_url     = "http://54.x.x.x"
backend_url      = "http://54.x.x.x:5000"
ssh_command      = "ssh -i portfolio-keypair.pem ubuntu@54.x.x.x"
```

> L'application met **~3-5 minutes** supplémentaires à démarrer (user_data en arrière-plan).

---

### Étape 4 — Vérifier le déploiement

```bash
# Récupérer l'IP
terraform output elastic_ip

# Attendre que l'init soit terminée (suivre les logs)
ssh -i portfolio-keypair.pem ubuntu@$(terraform output -raw elastic_ip)
tail -f /var/log/user_data.log

# Depuis l'EC2 : vérifier les containers
docker-compose -f /opt/anoors-portfolio/docker-compose.yml ps
```

---

### Étape 5 — Activer le remote state S3 (recommandé)

Après le premier apply, migrer le state vers S3 pour le partager avec Jenkins :

```bash
# 1. Récupérer l'Account ID créé
terraform output  # noter le bucket créé dans backend.tf

# 2. Décommenter le bloc backend dans provider.tf :
#    backend "s3" {
#      bucket         = "anoors-portfolio-tfstate-<ACCOUNT_ID>"
#      key            = "scenario1/terraform.tfstate"
#      region         = "us-east-1"
#      encrypt        = true
#      dynamodb_table = "anoors-portfolio-terraform-locks"
#    }

# 3. Migrer
terraform init -migrate-state
# Taper "yes" pour confirmer la migration
```

---

### Détruire l'infrastructure

```bash
terraform destroy -var-file="terraform.tfvars"
# Taper "yes" pour confirmer
```

> ⚠️ Supprimer l'Elastic IP **avant** de la détacher pour éviter des frais ($0.005/h si non attachée).

---

## Estimation des coûts Free Tier

| Ressource       | Free Tier (12 mois)    | Après Free Tier  |
|-----------------|------------------------|------------------|
| EC2 t2.micro    | 750h/mois              | ~$8.50/mois      |
| EBS gp2 20 Go   | 30 Go/mois             | ~$2/mois         |
| Elastic IP      | Gratuit si attachée    | $3.60/mois libre |
| Data transfer   | 1 Go sortant/mois      | $0.09/Go         |
| S3 state        | 5 Go/mois gratuit      | négligeable      |
| DynamoDB locks  | 25 Go gratuit          | négligeable      |
| **Total**       | **~$0**                | **~$10-15/mois** |

---

## Intégration Jenkins

Le pipeline `terraform/Jenkinsfile-terraform` gère tout automatiquement.

Credentials Jenkins à créer :

| ID                | Type              | Valeur                        |
|-------------------|-------------------|-------------------------------|
| `aws-credentials` | AWS Credentials   | Access Key + Secret Key AWS   |
| `dockerhub-creds` | Username/Password | Docker Hub                    |

Variables Terraform injectées par Jenkins :
```
-var="backend_image_tag=${BUILD_NUMBER}"
-var="frontend_image_tag=${BUILD_NUMBER}"
```

---

## Dépannage

**L'app ne répond pas après le apply**
```bash
# Se connecter et vérifier les logs d'init
ssh -i portfolio-keypair.pem ubuntu@<IP>
tail -100 /var/log/user_data.log
```

**Containers non démarrés**
```bash
cd /opt/anoors-portfolio
docker-compose ps
docker-compose logs -f
```

**Recréer les containers sans recréer l'EC2**
```bash
# Depuis l'EC2
cd /opt/anoors-portfolio
docker-compose pull
docker-compose up -d --force-recreate
```
