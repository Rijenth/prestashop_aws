#!/bin/bash
# Script pour mettre à jour automatiquement l'inventory Ansible avec l'IP de l'instance EC2

set -e

echo "====================================="
echo "Mise à jour de l'inventory Ansible"
echo "====================================="

# Se déplacer dans le répertoire Terraform
cd ../deploy

# Récupérer l'IP publique depuis Terraform
PUBLIC_IP=$(terraform output -raw prestashop_public_ip 2>/dev/null)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null)

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Erreur: Impossible de récupérer l'IP publique depuis Terraform"
    echo "Assurez-vous que 'terraform apply' a été exécuté avec succès"
    exit 1
fi

echo "✓ IP publique récupérée: $PUBLIC_IP"
echo "✓ RDS endpoint: $RDS_ENDPOINT"

# Revenir dans le répertoire Ansible
cd ../ansible

# Créer le fichier inventory avec l'IP
cat > inventory.ini << EOF
[prestashop]
$PUBLIC_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/prestashop-key

[prestashop:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

echo "✓ Fichier inventory.ini mis à jour avec succès"

# Mettre à jour le fichier de variables avec l'endpoint RDS
if [ -n "$RDS_ENDPOINT" ]; then
    export DB_ENDPOINT="$RDS_ENDPOINT"
    echo "✓ Variable DB_ENDPOINT exportée: $DB_ENDPOINT"
fi

echo ""
echo "====================================="
echo "✅ Inventory Ansible prêt !"
echo "====================================="
echo "Vous pouvez maintenant exécuter:"
echo "  ansible-playbook main.yml"
echo ""
