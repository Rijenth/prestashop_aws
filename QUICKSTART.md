# 🚀 Guide de démarrage rapide

Ce guide vous permet de déployer PrestaShop sur AWS en quelques minutes.

## ⚡ Déploiement en 3 étapes

### 1️⃣ Configuration (5 minutes)

```bash
# Générer une clé SSH
ssh-keygen -t rsa -b 4096 -f ~/.ssh/prestashop-key
chmod 600 ~/.ssh/prestashop-key

# Copier le fichier de configuration
cd deploy/
cp ../env/.env.dev.example ../env/.env.dev
# Éditer env/.env.dev avec toutes les variables TF_VAR_* requises
set -a
source ../env/.env.dev
set +a

# terraform.tfvars est optionnel (vous pouvez le laisser vide)
```

### 2️⃣ Infrastructure (5-10 minutes)

```bash
# Toujours dans le dossier deploy/
terraform init
terraform apply
# Tapez "yes" pour confirmer

# Notez l'IP publique affichée à la fin
```

### 3️⃣ Déploiement (5-10 minutes)

```bash
cd ../ansible/
./deploy.sh

# Le script fait tout automatiquement :
# ✅ Récupère l'IP depuis Terraform
# ✅ Configure l'inventory
# ✅ Installe Docker
# ✅ Déploie PrestaShop
```

## 🎉 C'est fini !

Accédez à votre boutique PrestaShop à l'URL affichée :
```
http://VOTRE_IP_PUBLIQUE
```

Admin : `http://VOTRE_IP_PUBLIQUE/admin-dev`

---

## 📚 Besoin de plus de détails ?

➡️ **Documentation complète** : [ansible/README.md](ansible/README.md)

Cette documentation contient :
- Tous les prérequis détaillés
- Comment obtenir vos credentials AWS
- Installation de Terraform et Ansible
- Dépannage et solutions

---

## 🛠️ Commandes utiles

### Voir les informations de déploiement
```bash
cd deploy/
terraform output
```

### Redéployer PrestaShop
```bash
cd ansible/
ansible-playbook deploy_prestashop.yml -e "db_server=$(cd ../deploy && terraform output -raw rds_endpoint)"
```

### Se connecter en SSH
```bash
ssh -i ~/.ssh/prestashop-key ubuntu@VOTRE_IP
```

### Voir les logs Docker
```bash
ssh -i ~/.ssh/prestashop-key ubuntu@VOTRE_IP "docker logs prestashop"
```

### Détruire l'infrastructure
```bash
cd deploy/
terraform destroy
# Tapez "yes" pour confirmer
```

---

## ⚠️ Important

- Si vous utilisez `terraform.tfvars`, **ne le commitez jamais**
- **Changez** le mot de passe de la base de données
- **Détruisez** l'infrastructure quand vous ne l'utilisez plus pour éviter les frais

---

## 💰 Coûts

- **12 premiers mois** : GRATUIT (AWS Free Tier)
- **Après** : ~10-15€/mois

---

## 🆘 Problèmes ?

1. Consultez [ansible/README.md#dépannage](ansible/README.md#dépannage)
2. Vérifiez les logs : `/var/log/user-data.log` sur EC2
3. Regardez les logs Docker : `docker logs prestashop`

---

**Bon déploiement ! 🚀**
