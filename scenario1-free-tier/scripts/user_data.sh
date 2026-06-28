#!/bin/bash
###############################################################
# user_data.sh — Script d'initialisation de l'EC2
# Exécuté automatiquement au premier démarrage de l'instance
#
# Convention d'échappement (templatefile Terraform) :
#   - Les variables destinées à être remplacées par Terraform sont écrites directement
#     dans le template (ex. backend_image_tag) et sont passées via la fonction
#     `templatefile(...)` depuis `main.tf`.
#   - Pour produire une variable bash littérale dans le fichier rendu,
#     écris son nom ici précédé d'un double-dollar (deux signes dollar). Cela évite
#     que Terraform n'essaie d'évaluer la séquence lors du rendu.
###############################################################

set -euo pipefail
LOG_FILE="/var/log/user_data.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "======================================================="
echo " Démarrage de l'initialisation : $$(date)"
echo "======================================================="

# ─── 1. Mise à jour du système ─────────────────────────────
echo "[1/6] Mise à jour des paquets..."
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  curl \
  wget \
  git \
  unzip \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common

# ─── 2. Installation de Docker ─────────────────────────────
echo "[2/6] Installation de Docker..."

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $$(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

echo "Docker version : $$(docker --version)"

# ─── 3. Installation de Docker Compose standalone ──────────
echo "[3/6] Installation de Docker Compose..."
COMPOSE_VERSION="v2.24.0"
curl -SL "https://github.com/docker/compose/releases/download/$${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "Docker Compose : $$(docker-compose --version)"

# ─── 4. Répertoire de l'application ────────────────────────
echo "[4/6] Création du répertoire de l'application..."
APP_DIR="/opt/${project_name}"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# ─── 5. Génération du docker-compose.yml ───────────────────
# Note : heredoc SANS quotes → Les variables passées depuis Terraform seront injectées
#        ici par la fonction `templatefile`. Si tu souhaites qu'une séquence ressemble
#        à une variable bash dans le fichier rendu, écris son nom précédé de deux
#        signes dollar dans ce template (deux dollars avant le nom).
echo "[5/6] Génération du docker-compose.yml..."

cat > "$APP_DIR/docker-compose.yml" <<COMPOSE_EOF
version: '3.8'

services:

  mongodb:
    image: mongo:6.0
    container_name: portfolio_mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: "${mongo_root_username}"
      MONGO_INITDB_ROOT_PASSWORD: "${mongo_root_password}"
      MONGO_INITDB_DATABASE: portfolio
    volumes:
      - mongodb_data:/data/db
    networks:
      - portfolio_network
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 40s

  backend:
    image: ${dockerhub_username}/portfolio-backend:${backend_image_tag}
    container_name: portfolio_backend
    restart: unless-stopped
    environment:
      NODE_ENV: production
      PORT: "${backend_port}"
      MONGODB_URI: "mongodb://${mongo_root_username}:${mongo_root_password}@mongodb:27017/portfolio?authSource=admin"
    ports:
      - "${backend_port}:${backend_port}"
    depends_on:
      mongodb:
        condition: service_healthy
    networks:
      - portfolio_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${backend_port}/api/test"]
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    image: ${dockerhub_username}/portfolio-frontend:${frontend_image_tag}
    container_name: portfolio_frontend
    restart: unless-stopped
    ports:
      - "${frontend_port}:80"
    depends_on:
      - backend
    networks:
      - portfolio_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  mongodb_data:
    driver: local

networks:
  portfolio_network:
    driver: bridge
COMPOSE_EOF

echo "docker-compose.yml généré :"
cat "$APP_DIR/docker-compose.yml"

# ─── 6. Démarrage de l'application ─────────────────────────
echo "[6/6] Démarrage avec Docker Compose..."
cd "$APP_DIR"
docker-compose pull
docker-compose up -d

# Attendre que les containers démarrent
sleep 20

echo ""
echo "======================================================="
echo " État des containers :"
docker-compose ps
echo ""
PUBLIC_IP=$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo " Frontend : http://$${PUBLIC_IP}"
echo " Backend  : http://$${PUBLIC_IP}:${backend_port}"
echo " Logs     : sudo docker-compose -f $APP_DIR/docker-compose.yml logs -f"
echo " Initialisation terminée : $$(date)"
echo "======================================================="
