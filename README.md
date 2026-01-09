# PrestaShop AWS - Déploiement automatisé avec Terraform et Ansible

Déploiement de PrestaShop sur AWS avec infrastructure **Free Tier** (gratuit pendant 12 mois).

Ce projet utilise :
- **Terraform** : Pour créer l'infrastructure AWS (VPC, EC2, RDS)
- **Ansible** : Pour automatiser la configuration et le déploiement de PrestaShop
- **Docker** : Pour exécuter PrestaShop dans un conteneur

## Développement Local

### Accès à la plateforme

**Frontend (Boutique):** http://localhost:8080

**Administration:** http://localhost:8080/admin-dev

**Identifiants:**
- Email: `demo@prestashop.com`
- Mot de passe: `prestashop_demo`

### Démarrer les services
```bash
docker-compose up -d
```

### Arrêt des services
```bash
docker-compose down
```

## 🚀 Déploiement automatisé sur AWS (Terraform + Ansible)

### Nouvelle méthode : Déploiement en 2 étapes

L'infrastructure Terraform utilise des ressources **gratuites** pendant 12 mois :
- **EC2 t2.micro** (750h/mois gratuit)
- **RDS db.t3.micro** (750h/mois gratuit)
- **20GB stockage** (gratuit)

### 📖 Documentation complète

➡️ **[Guide complet de déploiement avec Ansible (ansible/README.md)](ansible/README.md)**

Le guide contient :
- ✅ Tous les prérequis nécessaires (AWS, SSH, outils)
- ✅ Configuration AWS étape par étape
- ✅ Installation de Terraform et Ansible
- ✅ Déploiement complet automatisé
- ✅ Dépannage et solutions aux problèmes

### Déploiement rapide

**Étape 1 : Infrastructure avec Terraform**
```bash
cd deploy/

# 1. Configurer vos credentials
cp ../env/.env.dev.example ../env/.env.dev
# Éditer env/.env.dev (TF_VAR_* pour toutes les variables Terraform)
set -a
source ../env/.env.dev
set +a

# terraform.tfvars est optionnel (vous pouvez le laisser vide)

# 2. Déployer l'infrastructure
terraform init
terraform apply
```

**Étape 2 : Configuration avec Ansible**
```bash
cd ../ansible/

# Script automatique qui fait tout !
./deploy.sh
```

C'est tout ! Le script Ansible :
- ✅ Récupère automatiquement l'IP depuis Terraform
- ✅ Configure l'inventory
- ✅ Installe Docker sur EC2
- ✅ Déploie PrestaShop avec la bonne configuration
- ✅ Affiche l'URL d'accès

### Que fait Ansible ?

Ansible remplace l'ancien script `user_data` de Terraform et effectue :
1. Installation de Docker et ses dépendances
2. Configuration du serveur
3. Déploiement du conteneur PrestaShop
4. Connexion à la base de données RDS
5. Vérification du déploiement

### Structure du projet

```
prestashop_aws/
├── deploy/              # Infrastructure Terraform
│   ├── main.tf          # Configuration AWS
│   ├── vars.tf          # Variables
│   └── outputs.tf       # Outputs (IP, endpoints)
│
└── ansible/             # Configuration Ansible
    ├── README.md        # 📖 DOCUMENTATION COMPLÈTE
    ├── deploy.sh        # 🚀 Script de déploiement automatique
    ├── deploy_prestashop.yml  # Playbook principal
    └── group_vars/      # Variables de configuration
```

### Commandes Terraform utiles

```bash
cd deploy/

# Prévisualiser les changements
terraform plan

# Voir l'état actuel
terraform state list

# Voir les outputs (IP, URL, etc.)
terraform output

# Détruire l'infrastructure
terraform destroy
```

## Cache Redis (optimisé pour PrestaShop)

Un serveur Redis est inclus pour accélérer la mise en cache.

### Activer Redis dans PrestaShop
1. Back-office → **Paramètres avancés** → **Performances**
2. Activer le cache, puis choisir **Redis**
3. Hôte: `redis` / Port: `6379` / Timeout: `1`

Le fichier `redis/redis.conf` contient les réglages de cache (notamment `maxmemory`).
L'image PrestaShop inclut l'extension PHP `redis` via `docker/prestashop/Dockerfile`.

## Scripts

Installer un module depuis la derniere release GitHub:
```bash
bin/install-prestashop-module.sh <owner/repo>
```

Installer le module Redis Cache (NGS):
```bash
bin/install-ngs-redis-cache.sh
```

## Coût Estimé

- **Première année:** GRATUIT (AWS Free Tier)
- **Après 12 mois:** ~$25/mois (avec instances Free Tier)
- **Production (instances plus grandes):** ~$55/mois
