#!/bin/bash
# Script de déploiement complet PrestaShop avec Ansible

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  Déploiement PrestaShop avec Ansible${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Vérifier qu'Ansible est installé
if ! command -v ansible &> /dev/null; then
    echo -e "${RED}❌ Erreur: Ansible n'est pas installé${NC}"
    echo -e "${YELLOW}Installez Ansible avec: pip install ansible${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Ansible est installé${NC}"
ansible --version | head -1

# Vérifier que Terraform a été appliqué
if [ ! -d "../deploy/.terraform" ]; then
    echo -e "${RED}❌ Erreur: Terraform n'a pas été initialisé${NC}"
    echo -e "${YELLOW}Exécutez d'abord:${NC}"
    echo "  cd ../deploy"
    echo "  terraform init"
    echo "  terraform apply"
    exit 1
fi

echo -e "${GREEN}✓ Terraform a été initialisé${NC}"

# Mettre à jour l'inventory
echo ""
echo -e "${BLUE}Étape 1: Mise à jour de l'inventory Ansible${NC}"
./update_inventory.sh

# Récupérer l'endpoint RDS depuis Terraform
cd ../deploy
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null)
cd ../ansible

if [ -z "$RDS_ENDPOINT" ]; then
    echo -e "${RED}❌ Erreur: Impossible de récupérer l'endpoint RDS${NC}"
    exit 1
fi

export DB_ENDPOINT="$RDS_ENDPOINT"
echo -e "${GREEN}✓ Endpoint RDS: $DB_ENDPOINT${NC}"

# Tester la connexion SSH
echo ""
echo -e "${BLUE}Étape 2: Test de connexion SSH${NC}"
IP=$(grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' inventory.ini | head -1)

echo "Attente de 30 secondes pour s'assurer que l'instance est prête..."
sleep 30

if ansible prestashop -m ping; then
    echo -e "${GREEN}✓ Connexion SSH réussie${NC}"
else
    echo -e "${YELLOW}⚠ La connexion SSH a échoué, mais nous allons continuer...${NC}"
    echo -e "${YELLOW}Si le déploiement échoue, attendez quelques minutes et réessayez${NC}"
fi

# Exécuter le playbook Ansible
echo ""
echo -e "${BLUE}Étape 3: Déploiement de PrestaShop${NC}"
ansible-playbook main.yml -e "db_server=$DB_ENDPOINT"

echo ""
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}  ✅ Déploiement terminé avec succès !${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""
echo -e "Accédez à PrestaShop: ${BLUE}http://$IP${NC}"
echo -e "Admin: ${BLUE}http://$IP/admin-dev${NC}"
echo ""
