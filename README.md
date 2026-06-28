# Infrastructure AWS avec Terraform — Portfolio DevOps

Architecture complète en deux scénarios pour déployer l'application Full Stack sur AWS.

---

## Structure des fichiers

```
terraform/
├── README.md                          ← Ce fichier
├── Jenkinsfile-terraform              ← Pipeline CI/CD complet
│
├── scenario1-free-tier/               ← 100% Free Tier
│   ├── provider.tf                    ← Provider AWS + backend S3
│   ├── variables.tf                   ← Déclaration des variables
│   ├── terraform.tfvars               ← Valeurs (NE PAS COMMITTER)
│   ├── main.tf                        ← VPC, EC2, SG, EIP
│   ├── outputs.tf                     ← Valeurs exportées
│   ├── backend.tf                     ← S3 + DynamoDB pour le state
│   └── scripts/
│       └── user_data.sh               ← Init EC2 : Docker + Docker Compose
│
└── scenario2-eks/                     ← Architecture avancée EKS
    ├── provider.tf                    ← AWS + Kubernetes + Helm
    ├── variables.tf
    ├── terraform.tfvars
    ├── main.tf                        ← VPC, EKS, IAM, SG
    ├── outputs.tf
    ├── modules/
    │   └── eks_ref/main.tf            ← Module référence EKS
    └── k8s-manifests/
        ├── mongodb.yaml               ← StatefulSet MongoDB
        ├── backend.yaml               ← Deployment + Service backend
        ├── frontend.yaml              ← Deployment + Service frontend
        └── ingress.yaml               ← AWS ALB Ingress
```

---

## Prérequis

```bash
# Outils requis
terraform --version   # >= 1.6.0
aws --version         # AWS CLI v2
kubectl version       # Pour le scénario 2
docker --version

# Configuration AWS
aws configure
# AWS Access Key ID     : <votre-access-key>
# AWS Secret Access Key : <votre-secret-key>
# Default region        : us-east-1
# Default output format : json
```

---

## SCÉNARIO 1 — Free Tier (EC2 + Docker Compose)

### Architecture

```
Internet
    │
    ▼
[Elastic IP statique]
    │
    ▼
[Security Group]
 ├── :22   SSH
 ├── :80   Frontend React
 └── :5000 Backend API
    │
    ▼
[EC2 t2.micro — Ubuntu 22.04]
    │
    ├── [Docker Container : Nginx → React]   :80
    ├── [Docker Container : Node.js/Express] :5000
    └── [Docker Container : MongoDB]         :27017 (interne)
         └── [Volume EBS 20Go]
    │
    ▼
[VPC 10.0.0.0/16]
[Subnet public 10.0.1.0/24]
[Internet Gateway]
```

### Commandes

```bash
cd terraform/scenario1-free-tier

# 1. Initialiser Terraform (télécharge les providers)
terraform init

# 2. Valider la syntaxe
terraform validate

# 3. Voir ce qui sera créé (dry-run)
terraform plan -var-file="terraform.tfvars"

# 4. Créer l'infrastructure
terraform apply -var-file="terraform.tfvars"

# 5. Voir les outputs (URL, IP, commande SSH)
terraform output

# Se connecter en SSH
terraform output ssh_command | bash

# 6. Détruire l'infrastructure (stop facturation)
terraform destroy -var-file="terraform.tfvars"
```

### Estimation des coûts Free Tier

| Ressource       | Free Tier              | Au-delà          |
|-----------------|------------------------|------------------|
| EC2 t2.micro    | 750h/mois (12 mois)    | ~$0.0116/h       |
| EBS 20 Go       | 30 Go/mois (12 mois)   | ~$0.10/Go/mois   |
| Elastic IP      | Gratuit si attachée    | $0.005/h si libre|
| Data transfer   | 1 Go/mois              | $0.09/Go         |
| **Total**       | **~$0** (12 premiers mois) | **~$8-12/mois** |

---

## Checklist pour déployer le scénario AWS Free Tier

1. Vérifier les credentials Jenkins
   - `aws-credentials` : AWS Access Key + Secret Key
   - `dockerhub-creds` : Docker Hub username/password
   - (optionnel) `github-creds` pour l’accès SCM

2. Préparer les images Docker
   - Construire localement et tagger :
     - `anoor9s6/portfolio-backend:<tag>`
     - `anoor9s6/portfolio-frontend:<tag>`
   - Pusher sur Docker Hub si tu veux réutiliser `SKIP_BUILD=true`

3. Préparer le dossier Terraform
   - Vérifier `terraform/scenario1-free-tier/terraform.tfvars`
   - Ne pas committer ce fichier s’il contient des secrets
   - Vérifier que `terraform/scenario1-free-tier/terraform.tfvars` contient les bonnes valeurs pour `region`, `key_name`, `public_key_path`, `allowed_ips`, etc.

4. Lancer le pipeline Jenkins
   - Source : `terraform/Jenkinsfile-terraform`
   - Paramètres :
     - `TERRAFORM_SCENARIO` = `scenario1-free-tier`
     - `TERRAFORM_ACTION` = `plan`
     - `SKIP_BUILD` = `false` (ou `true` si images déjà poussées)
     - `IMAGE_TAG` = `latest` ou le tag souhaité
   - Exécuter `plan` d’abord pour vérifier
   - Vérifier l’output du plan avant `apply`

5. Appliquer l’infrastructure
   - Relancer le pipeline avec `TERRAFORM_ACTION = apply`
   - Confirmer l’étape manuelle dans Jenkins
   - Attendre la fin du déploiement

6. Vérifier le résultat
   - Se connecter en SSH : `terraform output ssh_command | bash`
   - Vérifier que Docker Compose tourne sur l’EC2
   - Vérifier le frontend sur l’IP Elastic et le backend sur le port 5000

7. Nettoyer après utilisation
   - Exécuter `terraform destroy -var-file="terraform.tfvars"`
   - Fermer le pipeline si nécessaire

---

## SCÉNARIO 2 — EKS (Architecture avancée)

> **Note:** Le scénario `scenario2-eks` est ignoré pour l'instant. N'utilisez pas ce scénario pour un déploiement Free Tier.

### Architecture

```
Internet
    │
    ▼
[AWS ALB — Application Load Balancer]
    │
    ▼
[EKS Cluster — Kubernetes 1.31]
    │
    ├── [Node Group : 2x t3.medium]
    │       │
    │       ├── Namespace: portfolio
    │       │   ├── Deployment: portfolio-frontend  (2 replicas)
    │       │   ├── Deployment: portfolio-backend   (2 replicas)
    │       │   └── StatefulSet: mongodb            (1 replica + PVC 5Go)
    │       │
    │       └── Services: ClusterIP + LoadBalancer
    │
    ▼
[VPC 10.0.0.0/16]
    ├── Subnet public  us-east-1a : 10.0.1.0/24  ← Nodes (sans NAT)
    ├── Subnet public  us-east-1b : 10.0.2.0/24
    ├── Subnet privé   us-east-1a : 10.0.10.0/24 ← Nodes (avec NAT)
    └── Subnet privé   us-east-1b : 10.0.11.0/24
```

### Commandes

```bash
cd terraform/scenario2-eks

# 1. Init
terraform init

# 2. Plan
terraform plan -var-file="terraform.tfvars"

# 3. Apply (15-20 min pour EKS)
terraform apply -var-file="terraform.tfvars"

# 4. Configurer kubectl
aws eks update-kubeconfig --region us-east-1 --name anoors-portfolio-eks

# 5. Déployer les manifests K8s
kubectl apply -f k8s-manifests/

# 6. Vérifier
kubectl get pods -n portfolio
kubectl get svc -n portfolio
kubectl get ingress -n portfolio

# 7. Détruire
terraform destroy -var-file="terraform.tfvars"
```

### Estimation des coûts EKS

| Ressource              | Coût mensuel estimé     |
|------------------------|-------------------------|
| EKS Control Plane      | $72/mois                |
| 2x t3.medium nodes     | ~$60/mois               |
| ALB                    | ~$16/mois               |
| NAT Gateway (optionel) | ~$32/mois               |
| EBS (PVC MongoDB)      | ~$0.50/mois             |
| **Total sans NAT**     | **~$148/mois**          |
| **Total avec NAT**     | **~$180/mois**          |

> ⚠️ EKS n'est pas éligible Free Tier. Utiliser uniquement pour un portfolio/démo, puis `terraform destroy`.

---

## Configuration Jenkins

### Credentials à créer dans Jenkins

| ID                  | Type                        | Description                    |
|---------------------|-----------------------------|--------------------------------|
| `aws-credentials`   | AWS Credentials             | Access Key + Secret Key AWS    |
| `dockerhub-creds`   | Username/Password           | Docker Hub login               |
| `github-creds`      | Username/Password ou SSH    | Accès au repo GitHub           |

### Ajouter le credential AWS

Jenkins → Manage Jenkins → Credentials → (global) → Add Credentials :
- Kind : `AWS Credentials`
- ID : `aws-credentials`
- Access Key ID : `<votre-access-key>`
- Secret Access Key : `<votre-secret-key>`

### Utiliser le pipeline Terraform

1. Créer un nouveau Pipeline Jenkins
2. Source : SCM → GitHub → `terraform/Jenkinsfile-terraform`
3. Lancer avec les paramètres :
    - `TERRAFORM_SCENARIO` : `scenario1-free-tier`
   - `TERRAFORM_ACTION` : `plan` → vérifier → `apply`
   - `IMAGE_TAG` : tag des images Docker

---

## Bonnes pratiques appliquées

**Terraform**
- State distant sur S3 avec versioning et chiffrement
- Locks DynamoDB pour éviter les modifications concurrentes
- Variables typées avec validation
- Outputs documentés
- `prevent_destroy` sur les ressources critiques
- Tags systématiques sur toutes les ressources

**Sécurité**
- Volume EBS chiffré
- Secrets dans `terraform.tfvars` (hors VCS)
- Security Groups restrictifs (SSH limité à votre IP)
- IAM Roles avec principe du moindre privilège
- Secrets Kubernetes pour les credentials MongoDB

**DevOps**
- Pipeline avec approbation manuelle avant `apply`/`destroy`
- Notification email succès/échec
- `terraform validate` systématique
- Tags `ManagedBy: Terraform` sur toutes les ressources

---

## Fichiers à ajouter au .gitignore

```gitignore
# Terraform
terraform/**/*.tfvars
terraform/**/.terraform/
terraform/**/.terraform.lock.hcl
terraform/**/tfplan
terraform/**/*.pem
terraform/**/terraform_outputs.json
```
