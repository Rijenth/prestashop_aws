#!/bin/bash
# Script de déploiement complet PrestaShop avec Ansible

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  Déploiement PrestaShop avec Ansible${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

ENV_NAME="${1:-${DEPLOY_ENV:-dev}}"
ENV_FILE="../env/.env.${ENV_NAME}"
INVENTORY_PATH="inventories/${ENV_NAME}/inventory.ini"

if [ -f "${ENV_FILE}" ]; then
    set -a
    # shellcheck disable=SC1090
    . "${ENV_FILE}"
    set +a
    echo -e "${GREEN}✓ Variables chargées: ${ENV_FILE}${NC}"
fi

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
./update_inventory.sh "${ENV_NAME}"

# Tester la connexion SSH
echo ""
echo -e "${BLUE}Étape 2: Test de connexion SSH${NC}"
IP=$(grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "${INVENTORY_PATH}" | head -1)

echo "Attente de 30 secondes pour s'assurer que l'instance est prête..."
sleep 5

if ansible -i "${INVENTORY_PATH}" prestashop -m ping; then
    echo -e "${GREEN}✓ Connexion SSH réussie${NC}"
else
    echo -e "${YELLOW}⚠ La connexion SSH a échoué, mais nous allons continuer...${NC}"
    echo -e "${YELLOW}Si le déploiement échoue, attendez quelques minutes et réessayez${NC}"
fi

# Exécuter le playbook Ansible
echo ""
echo -e "${BLUE}Étape 3: Déploiement de PrestaShop${NC}"
ansible-playbook -i "${INVENTORY_PATH}" deploy_prestashop.yml

echo ""
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}  ✅ Déploiement terminé avec succès !${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""
echo -e "Accédez à PrestaShop: ${BLUE}http://$IP${NC}"
echo -e "Admin: ${BLUE}http://$IP/admin-dev${NC}"
echo ""
