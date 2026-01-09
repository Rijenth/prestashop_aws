# Déploiement PrestaShop avec Ansible sur AWS

Ce guide vous explique comment déployer automatiquement PrestaShop sur AWS en utilisant Terraform pour l'infrastructure et Ansible pour la configuration.

## 📋 Table des matières

1. [Prérequis](#prérequis)
2. [Architecture](#architecture)
3. [Configuration AWS](#configuration-aws)
4. [Installation des outils](#installation-des-outils)
5. [Configuration SSH](#configuration-ssh)
6. [Déploiement](#déploiement)
7. [Structure du projet](#structure-du-projet)
8. [Dépannage](#dépannage)

---

## 🎯 Prérequis

### Sur votre machine locale

Vous devez avoir installé :
- **Terraform** (>= 1.0)
- **Ansible** (>= 2.9)
- **AWS CLI** (optionnel mais recommandé)
- **Python 3** (>= 3.8)
- **SSH client**

### Dans AWS

Vous devez avoir :
- Un **compte AWS** avec accès Free Tier (si possible)
- Des **credentials AWS** (Access Key + Secret Key)
- Les **permissions nécessaires** pour créer :
  - VPC, Subnets, Internet Gateway, Route Tables
  - Security Groups
  - EC2 instances (t2.micro)
  - RDS instances (db.t3.micro)
  - Elastic IP

---

## 🏗️ Architecture

Le déploiement crée l'infrastructure suivante sur AWS :

```
┌─────────────────────────────────────────────────────┐
│                    AWS Region                       │
│                                                     │
│  ┌───────────────────────────────────────────────-┐ │
│  │              VPC (10.0.0.0/16)                 │ │
│  │                                                │ │
│  │  ┌─────────────────┐  ┌──────────────────┐     │ │
│  │  │ Public Subnet   │  │ Private Subnets  │     │ │
│  │  │ (10.0.1.0/24)   │  │ (10.0.2.0/24)    │     │ │
│  │  │                 │  │ (10.0.3.0/24)    │     │ │
│  │  │  ┌──────────┐   │  │                  │     │ │
│  │  │  │   EC2    │   │  │  ┌───────────┐   │     │ │
│  │  │  │PrestaShop│───┼──┼─▶│    RDS    │   │     │ │
│  │  │  │ + Docker │   │  │  │   MySQL   │   │     │ │
│  │  │  └────┬─────┘   │  │  └───────────┘   │     │ │
│  │  │       │         │  │                  │     │ │
│  │  └───────┼─────────┘  └──────────────────┘     │ │
│  │          │                                     │ │
│  └──────────┼──────────────────────────────────-─-┘ │
│             │                                       │
│      ┌──────▼────────┐                              │
│      │ Internet GW   │                              │
│      └───────────────┘                              │
└───────────────────────────────────────────────────--┘
              │
              ▼
          Internet
```

**Composants :**
- **VPC** : Réseau virtuel isolé
- **Subnet public** : Pour l'instance EC2 (accessible depuis Internet)
- **Subnets privés** : Pour la base de données RDS (non accessible depuis Internet)
- **EC2 (t2.micro)** : Serveur web avec Docker et PrestaShop
- **RDS MySQL (db.t3.micro)** : Base de données managée
- **Security Groups** : Règles de pare-feu
- **Elastic IP** : IP publique fixe pour EC2

---

## ⚙️ Configuration AWS

### 1. Créer vos credentials AWS

1. Connectez-vous à la [Console AWS](https://console.aws.amazon.com/)
2. Allez dans **IAM** (Identity and Access Management)
3. Dans le menu, cliquez sur **Users** (Utilisateurs)
4. Cliquez sur votre utilisateur (ou créez-en un)
5. Allez dans l'onglet **Security credentials**
6. Dans la section **Access keys**, cliquez sur **Create access key**
7. Choisissez le cas d'usage : **Command Line Interface (CLI)**
8. Cochez "I understand..." et cliquez sur **Next**
9. Notez votre **Access Key ID** et **Secret Access Key** ⚠️ (vous ne pourrez plus voir la secret key après)

### 2. Configuration des variables Terraform

Créez un fichier de secrets et chargez-le :

```bash
cp env/.env.dev.example env/.env.dev
# Remplacez les valeurs de:
# - TF_VAR_AWS_ACCESS_KEY / TF_VAR_AWS_SECRET_KEY
# - TF_VAR_SSH_PUBLIC_KEY
# - TF_VAR_AWS_REGION / TF_VAR_INSTANCE_TYPE / TF_VAR_DB_INSTANCE_CLASS
# - TF_VAR_DB_NAME / TF_VAR_DB_USER / TF_VAR_DB_PASSWORD
set -a
source env/.env.dev
set +a
```

`terraform.tfvars` est optionnel (vous pouvez le laisser vide).

⚠️ **Important** : Ne commitez JAMAIS vos credentials dans Git !

---

## 🔑 Configuration SSH

### 1. Générer une paire de clés SSH

Si vous n'avez pas encore de clé SSH :

```bash
# Générer une nouvelle paire de clés
ssh-keygen -t rsa -b 4096 -f ~/.ssh/prestashop-key -C "prestashop@aws"

# Appuyez sur Entrée pour laisser la passphrase vide (ou définissez-en une)
```

Cela crée deux fichiers :
- `~/.ssh/prestashop-key` : Clé privée (gardez-la secrète !)
- `~/.ssh/prestashop-key.pub` : Clé publique (à mettre dans Terraform)

### 2. Copier la clé publique

```bash
# Afficher votre clé publique
cat ~/.ssh/prestashop-key.pub
```

Copiez tout le contenu (commence par `ssh-rsa` ou `ssh-ed25519`) et collez-le dans `TF_VAR_SSH_PUBLIC_KEY` dans `env/.env.dev`.

### 3. Configurer les permissions (Important !)

```bash
# La clé privée doit avoir les bonnes permissions
chmod 600 ~/.ssh/prestashop-key
chmod 644 ~/.ssh/prestashop-key.pub
```

---

## 📦 Installation des outils

### Installation de Terraform

**macOS** (avec Homebrew) :
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Linux** :
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Windows** (avec Chocolatey) :
```powershell
choco install terraform
```

Vérification :
```bash
terraform --version
```

### Installation d'Ansible

**macOS** :
```bash
brew install ansible
```

**Linux** :
```bash
sudo apt update
sudo apt install ansible -y
# ou avec pip
pip3 install ansible
```

**Windows** :
Ansible ne fonctionne pas nativement sur Windows. Utilisez WSL2 (Windows Subsystem for Linux) :
```bash
# Dans WSL2
sudo apt update
sudo apt install ansible -y
```

Vérification :
```bash
ansible --version
```

### Installation du module Python Docker pour Ansible

```bash
pip3 install docker docker-compose
```

---

## 🚀 Déploiement

### Étape 1 : Déployer l'infrastructure avec Terraform

```bash
# 1. Aller dans le dossier Terraform
cd deploy/

# 2. Initialiser Terraform (télécharge les providers)
terraform init

# 3. Vérifier ce qui va être créé
terraform plan

# 4. Créer l'infrastructure sur AWS
terraform apply

# Tapez "yes" pour confirmer
```

⏱️ **Durée** : ~5-10 minutes (surtout pour RDS)

À la fin, Terraform affiche :
```
Outputs:

prestashop_url = "http://13.36.XXX.XXX"
prestashop_public_ip = "13.36.XXX.XXX"
rds_endpoint = "prestashop-db.xxxxx.eu-west-3.rds.amazonaws.com:3306"
ssh_connection_command = "ssh -i ~/.ssh/prestashop-key ubuntu@13.36.XXX.XXX"
```

### Étape 2 : Déployer PrestaShop avec Ansible

```bash
# 1. Aller dans le dossier Ansible
cd ../ansible/

# 2. Exécuter le script de déploiement automatique
./deploy.sh

# Optionnel: choisir un environnement
# DEPLOY_ENV=staging ./deploy.sh

# Optionnel: charger des variables d'env (deploy.sh les charge automatiquement)
# cp ../env/.env.dev.example ../env/.env.dev
```

Le script fait automatiquement :
1. ✅ Vérifie qu'Ansible est installé
2. ✅ Récupère l'IP publique depuis Terraform
3. ✅ Met à jour l'inventory Ansible
4. ✅ Teste la connexion SSH
5. ✅ Exécute le playbook Ansible

⏱️ **Durée** : ~5-10 minutes

### Étape 3 : Accéder à PrestaShop

Une fois le déploiement terminé, vous verrez :

```
========================================
  ✅ Déploiement terminé avec succès !
========================================

Accédez à PrestaShop: http://13.36.XXX.XXX
Admin: http://13.36.XXX.XXX/admin-dev
```

Ouvrez votre navigateur et accédez à l'URL affichée !

**Identifiants par défaut :**
- Email : `demo@prestashop.com`
- Mot de passe : `prestashop_demo`

---

## 📁 Structure du projet

```
prestashop_aws/
├── deploy/                      # Infrastructure Terraform
│   ├── main.tf                  # Configuration principale
│   ├── vars.tf                  # Définition des variables
│   ├── outputs.tf               # Outputs (IP, endpoints, etc.)
│   ├── terraform.tfvars         # Optionnel (souvent vide)
│   ├── environments/            # Exemples par environnement
│   │   ├── dev.tfvars.example
│   │   ├── staging.tfvars.example
│   │   └── prod.tfvars.example
│   └── terraform.tf             # Configuration du provider
│
├── ansible/                     # Configuration Ansible
│   ├── ansible.cfg              # Configuration Ansible
│   ├── deploy_prestashop.yml    # Playbook principal
│   ├── group_vars/
│   │   └── all.yml              # Variables communes
│   ├── inventories/             # Inventaires par environnement
│   │   ├── dev/
│   │   │   ├── inventory.ini            # Généré automatiquement
│   │   │   └── group_vars/
│   │   │       └── prestashop.yml
│   ├── deploy.sh                # Script de déploiement automatique
│   ├── update_inventory.sh      # Script de mise à jour inventory
│   └── README.md                # Ce fichier !
│
├── env/                         # Variables d'env par environnement
│   ├── .env.dev.example
│   ├── .env.staging.example
│   └── .env.prod.example
│
└── docker-compose.yml           # Configuration Docker (dev local)
```

---

## 🔧 Gestion des variables

Ordre recommandé (du plus prioritaire au moins prioritaire) :
- `env/.env.<env>` pour les secrets (chargé par `deploy.sh`)
- `ansible/inventories/<env>/group_vars/prestashop.yml` pour les overrides d'environnement
- `ansible/inventories/<env>/group_vars/prestashop/terraform_outputs.yml` pour les valeurs infra
- `ansible/group_vars/all.yml` pour les defaults globaux

---

## 🔧 Que fait le playbook Ansible ?

Le playbook `deploy_prestashop.yml` effectue les tâches suivantes sur l'instance EC2 :

1. **Installation des prérequis système**
   - Mise à jour des paquets Ubuntu
   - Installation de Python, curl, netcat, etc.

2. **Installation de Docker**
   - Ajout du dépôt officiel Docker
   - Installation de Docker CE et Docker Compose
   - Démarrage du service Docker
   - Ajout de l'utilisateur ubuntu au groupe docker

3. **Vérification de la base de données**
   - Attente que RDS soit accessible (port 3306)
   - Timeout de 5 minutes

4. **Déploiement de PrestaShop**
   - Récupération de l'IP publique de l'instance
   - Création du conteneur Docker PrestaShop
   - Configuration des variables d'environnement (DB, domaine, etc.)
   - Démarrage du conteneur avec restart automatique

5. **Vérification**
   - Vérification de l'état du conteneur
   - Affichage des logs

---

## 🛠️ Utilisation manuelle (sans le script)

Si vous préférez exécuter les étapes manuellement :

### 1. Mettre à jour l'inventory

```bash
cd ansible/
./update_inventory.sh dev
```

Ou manuellement, éditez `ansible/inventories/dev/inventory.ini` :
```ini
[prestashop]
13.36.XXX.XXX ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/prestashop-key

[prestashop:vars]
ansible_python_interpreter=/usr/bin/python3
```

### 2. Tester la connexion

```bash
ansible -i inventories/dev/inventory.ini prestashop -m ping
```

Vous devriez voir :
```
13.36.XXX.XXX | SUCCESS => {
    "ping": "pong"
}
```

### 3. Exécuter le playbook

```bash
cd ../ansible/
ansible-playbook -i inventories/dev/inventory.ini deploy_prestashop.yml
```

---

## 🐛 Dépannage

### Problème : "Permission denied (publickey)"

**Cause** : La clé SSH n'est pas accessible ou n'a pas les bonnes permissions.

**Solution** :
```bash
# Vérifier les permissions
ls -la ~/.ssh/prestashop-key

# Les corriger si nécessaire
chmod 600 ~/.ssh/prestashop-key
```

### Problème : "Host key verification failed"

**Cause** : SSH demande de vérifier l'empreinte de l'hôte.

**Solution** : C'est déjà géré dans `ansible.cfg` avec `host_key_checking = False`. Si le problème persiste :
```bash
ssh-keyscan -H 13.36.XXX.XXX >> ~/.ssh/known_hosts
```

### Problème : Ansible ne peut pas se connecter

**Solutions** :
1. Vérifiez que l'instance EC2 est bien démarrée dans la console AWS
2. Vérifiez le Security Group (port 22 doit être ouvert)
3. Attendez 2-3 minutes après le `terraform apply` (l'instance doit finir de démarrer)
4. Testez la connexion SSH directement :
```bash
ssh -i ~/.ssh/prestashop-key ubuntu@13.36.XXX.XXX
```

### Problème : "Timeout waiting for RDS"

**Cause** : RDS met du temps à démarrer ou n'est pas accessible.

**Solution** :
1. Vérifiez dans la console AWS que RDS est "Available"
2. Vérifiez les Security Groups (EC2 doit pouvoir accéder à RDS sur le port 3306)
3. Relancez le playbook :
```bash
ansible-playbook deploy_prestashop.yml -e "db_server=$RDS_ENDPOINT"
```

### Problème : PrestaShop ne s'affiche pas

**Solutions** :
1. Attendez 2-3 minutes (PrestaShop met du temps à s'installer)
2. Vérifiez que le conteneur tourne :
```bash
ssh -i ~/.ssh/prestashop-key ubuntu@IP_PUBLIQUE
docker ps
docker logs prestashop
```
3. Vérifiez que le port 80 est bien ouvert dans le Security Group

### Problème : "Error installing Docker"

**Cause** : L'instance n'a pas accès à Internet ou les dépôts sont temporairement indisponibles.

**Solution** :
1. Vérifiez qu'Internet Gateway est bien attaché au VPC
2. Vérifiez la route table du subnet public
3. Relancez le playbook

---

## 🔄 Redéploiement

Pour redéployer PrestaShop (sans toucher à l'infrastructure) :

```bash
cd ansible/
ansible-playbook deploy_prestashop.yml -e "db_server=$(cd ../deploy && terraform output -raw rds_endpoint)"
```

---

## 🗑️ Nettoyage

Pour supprimer toute l'infrastructure AWS et éviter les frais :

```bash
cd deploy/
terraform destroy

# Tapez "yes" pour confirmer
```

⚠️ **Attention** : Cela supprimera **TOUT** (EC2, RDS, VPC, données PrestaShop, etc.)

---

## 📚 Ressources supplémentaires

- [Documentation Terraform AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Documentation Ansible](https://docs.ansible.com/)
- [Documentation PrestaShop](https://doc.prestashop.com/)
- [AWS Free Tier](https://aws.amazon.com/free/)

---

## 🎓 Pour aller plus loin

### Améliorer la sécurité

1. **Restreindre l'accès SSH** : Modifiez le Security Group pour n'autoriser que votre IP :
```hcl
# Dans deploy/main.tf
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["VOTRE_IP/32"]  # Remplacez par votre IP
}
```

2. **Utiliser AWS Secrets Manager** pour stocker les mots de passe

3. **Ajouter HTTPS** avec Let's Encrypt et un nom de domaine

### Ajouter de la supervision

1. **CloudWatch** : Activer les métriques CloudWatch sur EC2 et RDS
2. **Logs** : Centraliser les logs Docker dans CloudWatch Logs
3. **Alertes** : Créer des alarmes CloudWatch (CPU, mémoire, etc.)

### Sauvegardes automatiques

1. **RDS Backups** : Activer les snapshots automatiques
2. **EBS Snapshots** : Créer des snapshots du volume EC2
3. **PrestaShop data** : Exporter régulièrement le volume Docker

---

## 📞 Support

Pour toute question ou problème :
1. Vérifiez la section [Dépannage](#dépannage)
2. Consultez les logs : `/var/log/user-data.log` sur EC2
3. Regardez les logs Docker : `docker logs prestashop`

---

**Bon déploiement ! 🚀**
