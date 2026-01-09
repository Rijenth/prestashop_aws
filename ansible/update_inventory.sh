#!/bin/bash
# Script pour mettre à jour automatiquement l'inventory Ansible avec l'IP de l'instance EC2

set -e

ENV_NAME="${1:-${DEPLOY_ENV:-dev}}"
INVENTORY_DIR="inventories/${ENV_NAME}"
GROUP_VARS_DIR="${INVENTORY_DIR}/group_vars"
PRESTASHOP_GROUP_VARS_DIR="${GROUP_VARS_DIR}/prestashop"

echo "====================================="
echo "Mise à jour de l'inventory Ansible"
echo "====================================="
echo "Environnement: ${ENV_NAME}"

# Se déplacer dans le répertoire Terraform
cd ../deploy

# Récupérer l'IP publique depuis Terraform
PUBLIC_IP=$(terraform output -raw prestashop_public_ip 2>/dev/null)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null)
RDS_DB_NAME=$(terraform output -raw rds_database_name 2>/dev/null)
RDS_DB_USER=$(terraform output -raw rds_database_user 2>/dev/null)

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Erreur: Impossible de récupérer l'IP publique depuis Terraform"
    echo "Assurez-vous que 'terraform apply' a été exécuté avec succès"
    exit 1
fi

echo "✓ IP publique récupérée: $PUBLIC_IP"
echo "✓ RDS endpoint: $RDS_ENDPOINT"

# Revenir dans le répertoire Ansible
cd ../ansible

# Créer les repertoires d'inventory
mkdir -p "${PRESTASHOP_GROUP_VARS_DIR}"

# Créer le fichier inventory avec l'IP
cat > "${INVENTORY_DIR}/inventory.ini" << EOF
[prestashop]
$PUBLIC_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/prestashop-key

[prestashop:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

echo "✓ Fichier ${INVENTORY_DIR}/inventory.ini mis à jour avec succès"

if [ -n "$RDS_ENDPOINT" ]; then
    {
        echo "---"
        echo "db_server: \"${RDS_ENDPOINT}\""
        echo "prestashop_public_ip: \"${PUBLIC_IP}\""
        if [ -n "$RDS_DB_NAME" ]; then
            echo "db_name: \"${RDS_DB_NAME}\""
        fi
        if [ -n "$RDS_DB_USER" ]; then
            echo "db_user: \"${RDS_DB_USER}\""
        fi
    } > "${PRESTASHOP_GROUP_VARS_DIR}/terraform_outputs.yml"
    echo "✓ Variables Terraform ecrites dans ${PRESTASHOP_GROUP_VARS_DIR}/terraform_outputs.yml"
fi

echo ""
echo "====================================="
echo "✅ Inventory Ansible prêt !"
echo "====================================="
echo "Vous pouvez maintenant exécuter:"
echo "  ansible-playbook -i ${INVENTORY_DIR}/inventory.ini deploy_prestashop.yml"
echo ""
