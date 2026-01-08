# Guide de Déploiement et d'Exploitation

## Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Configuration Initiale](#configuration-initiale)
4. [Déploiement en Développement](#déploiement-en-développement)
5. [Déploiement en Production AWS](#déploiement-en-production-aws)
6. [Exploitation et Maintenance](#exploitation-et-maintenance)
7. [Monitoring et Surveillance](#monitoring-et-surveillance)
8. [Sauvegardes et Restauration](#sauvegardes-et-restauration)
9. [Dépannage](#dépannage)
10. [Sécurité](#sécurité)
11. [Mises à Jour](#mises-à-jour)
12. [Bonnes Pratiques](#bonnes-pratiques)

---

## Vue d'ensemble

Ce projet déploie une plateforme e-commerce PrestaShop avec deux environnements distincts :

- **Environnement de développement** : Docker Compose pour tester localement
- **Environnement de production** : Infrastructure AWS provisionnée via Terraform

### Architecture de Production

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

---

## Prérequis

### Pour le Développement Local

- **Docker** : version 20.10 ou supérieure
- **Docker Compose** : version 2.0 ou supérieure
- **Git** : pour cloner le repository

### Pour le Déploiement AWS

- **Compte AWS** : avec accès Free Tier si possible
- **Terraform** (>= 1.0)
- **Ansible** (>= 2.9)
- **AWS CLI** (optionnel mais recommandé)
- **Python 3** (>= 3.8)
- **SSH client**
- **Paire de clés SSH** : pour accéder à l'instance EC2

### Vérification des Prérequis

```bash
# Vérifier Docker
docker --version
docker-compose --version

# Vérifier Terraform
terraform --version

# Vérifier AWS CLI (optionnel)
aws --version

# Vérifier Git
git --version
```

---

## Configuration Initiale

### 1. Cloner le Repository

```bash
git clone https://github.com/Rijenth/prestashop_aws
cd prestashop_aws
```

### 2. Structure du Projet

```
prestashop_aws/
├── docker-compose.yml          # Configuration Docker locale
├── deploy/                     # Infrastructure AWS
│   ├── main.tf                # Définition infrastructure
│   ├── vars.tf                # Variables Terraform
│   ├── outputs.tf             # Sorties Terraform
│   ├── terraform.tf           # Configuration provider
│   └── terraform.tfvars.example  # Exemple de variables
├── README.md                   # Documentation technique
└── DEPLOY.md                   # Ce guide
```

---

## Déploiement en Développement

### Démarrage de l'Environnement Local

#### 1. Lancer les Services

```bash
# Démarrer PrestaShop et MySQL en arrière-plan
docker-compose up -d
```

#### 2. Vérifier le Démarrage

```bash
# Vérifier l'état des conteneurs
docker-compose ps

# Suivre les logs en temps réel
docker-compose logs -f prestashop

# Attendre que l'installation soit terminée (environ 2-3 minutes)
```

#### 3. Accéder à PrestaShop

Une fois l'installation terminée :

- **Boutique** : http://localhost:8080
- **Panneau Admin** : http://localhost:8080/admin-dev

**Identifiants par défaut** :
- Email : `demo@prestashop.com`
- Mot de passe : `prestashop_demo`

### Gestion de l'Environnement Local

#### Arrêter les Services

```bash
# Arrêter sans supprimer les données
docker-compose stop

# Arrêter et supprimer les conteneurs (données préservées dans les volumes)
docker-compose down
```

#### Consulter les Logs

```bash
# Logs PrestaShop
docker-compose logs -f prestashop

# Logs MySQL
docker-compose logs -f mysql

# Logs des deux services
docker-compose logs -f
```

#### Redémarrer les Services

```bash
# Redémarrage complet
docker-compose restart

# Redémarrer un service spécifique
docker-compose restart prestashop
```

#### Réinitialiser l'Environnement

```bash
# ATTENTION : Supprime toutes les données !
docker-compose down -v

# Redémarrer proprement
docker-compose up -d
```

---

## Déploiement en Production AWS

### Étape 1 : Préparation des Credentials AWS

#### Créer un Utilisateur IAM

1. Connectez-vous à la [Console AWS IAM](https://console.aws.amazon.com/iam/)
2. Créez un nouvel utilisateur avec accès programmatique
3. Attachez les permissions nécessaires :
   - `AmazonEC2FullAccess`
   - `AmazonRDSFullAccess`
   - `AmazonVPCFullAccess`
4. Notez l'**Access Key** et la **Secret Key**

#### Générer une Paire de Clés SSH

```bash
# Générer une nouvelle clé SSH
ssh-keygen -t rsa -b 4096 -f ~/.ssh/prestashop_aws -C "prestashop-aws"

# Afficher la clé publique (à copier pour Terraform)
cat ~/.ssh/prestashop_aws.pub
```

### Étape 2 : Configuration Terraform

#### 1. Créer le Fichier de Variables

```bash
cd deploy/
cp terraform.tfvars.example terraform.tfvars
```

#### 2. Éditer `terraform.tfvars`

```bash
nano terraform.tfvars
# ou
vim terraform.tfvars
```

Remplissez les variables **obligatoires** :

```hcl
# Credentials AWS
AWS_ACCESS_KEY = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Clé SSH publique (contenu de ~/.ssh/prestashop_aws.pub)
SSH_PUBLIC_KEY = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACA... prestashop-aws"

# Mot de passe base de données (CHANGEZ-LE !)
DB_PASSWORD = "VotreMotDePasseTresFort123!@#"
```

Variables **optionnelles** (ont des valeurs par défaut) :

```hcl
# Région AWS (défaut: eu-west-3 - Paris)
AWS_REGION = "eu-west-3"

# Type d'instance EC2 (défaut: t2.micro - Free Tier)
INSTANCE_TYPE = "t2.micro"

# Type d'instance RDS (défaut: db.t3.micro - Free Tier)
DB_INSTANCE_CLASS = "db.t3.micro"

# Nom de la base de données (défaut: prestashop)
DB_NAME = "prestashop"

# Utilisateur de la base de données (défaut: prestashop_admin)
DB_USER = "prestashop_admin"
```

#### 3. Sécuriser le Fichier

```bash
# Rendre le fichier accessible uniquement par vous
chmod 600 terraform.tfvars

# Vérifier qu'il est bien ignoré par Git
cat ../.gitignore | grep terraform.tfvars
```

### Étape 3 : Initialisation de Terraform

```bash
# Se placer dans le dossier deploy/
cd deploy/

# Initialiser Terraform (télécharge le provider AWS)
terraform init

# Vérifier la configuration
terraform fmt
terraform validate
```

### Étape 4 : Planification du Déploiement

```bash
# Générer un plan de déploiement
terraform plan
```

**Vérifiez attentivement** :
- Les ressources qui vont être créées
- Les coûts estimés (gratuit avec Free Tier)
- La région de déploiement

### Étape 5 : Déploiement de l'Infrastructure

```bash
# Appliquer le plan (avec confirmation)
terraform apply

# Ou utiliser le plan sauvegardé
terraform apply tfplan
```

**Durée estimée** : 10-15 minutes

Le déploiement va créer :
- 1 VPC avec subnets
- 1 Internet Gateway
- 1 instance EC2 avec Elastic IP
- 1 base de données RDS MySQL
- Groupes de sécurité et routes

### Étape 6 : Récupération des Informations de Déploiement

À la fin du déploiement, Terraform affiche les informations importantes :

```bash
# Exemple de sortie
Outputs:

prestashop_url = "http://52.47.123.45"
prestashop_admin_url = "http://52.47.123.45/admin-dev"
ec2_public_ip = "52.47.123.45"
ssh_connection_command = "ssh -i /path/to/your/ssh_keys.pem ubuntu@52.47.123.45"
rds_endpoint = "prestashop-db.xxxxx.eu-west-3.rds.amazonaws.com:3306"
```

**Sauvegardez ces informations** dans un endroit sécurisé !

### Étape 7 : Vérification du Déploiement

#### 1. Vérifier l'Installation PrestaShop

```bash
# Se connecter à l'instance EC2
ssh -i ~/.ssh/prestashop_aws ubuntu@<EC2_PUBLIC_IP>

# Vérifier que Docker fonctionne
docker ps

# Vérifier les logs PrestaShop
docker logs -f $(docker ps -q --filter ancestor=prestashop/prestashop)
```

#### 2. Accéder à PrestaShop

Attendez 5-10 minutes après le déploiement pour que PrestaShop termine son installation.

- **URL de la boutique** : Utilisez l'URL fournie dans les outputs Terraform
- **Panneau Admin** : URL + `/admin-dev`

### Étape 8 : Configuration Post-Déploiement

Une fois connecté via SSH à l'instance EC2 :

```bash
# Vérifier l'état du conteneur PrestaShop
docker ps

# Vérifier les logs pour l'installation
docker logs prestashop

# Vérifier la connexion à la base de données
docker exec -it $(docker ps -q) ps aux | grep mysql
```

---

## Exploitation et Maintenance

### Opérations Quotidiennes

#### Surveillance des Services

```bash
# Se connecter à l'instance EC2
ssh -i ~/.ssh/prestashop_aws ubuntu@<EC2_PUBLIC_IP>

# Vérifier que PrestaShop fonctionne
docker ps
curl -I http://localhost

# Vérifier l'utilisation des ressources
top
df -h
free -m
```

#### Consultation des Logs

```bash
# Logs PrestaShop (temps réel)
docker logs -f --tail 100 $(docker ps -q --filter ancestor=prestashop/prestashop)

# Logs système
sudo journalctl -u docker -f

# Logs Apache dans le conteneur
docker exec $(docker ps -q) tail -f /var/log/apache2/error.log
```

### Gestion de l'Infrastructure Terraform

#### Voir l'État Actuel

```bash
cd deploy/

# Lister toutes les ressources gérées
terraform state list

# Afficher les détails d'une ressource
terraform state show aws_instance.prestashop_web

# Synchroniser l'état avec AWS
terraform refresh
```

#### Modifier l'Infrastructure

```bash
# Modifier terraform.tfvars ou les fichiers .tf
nano terraform.tfvars

# Prévisualiser les changements
terraform plan

# Appliquer les modifications
terraform apply
```

#### Détruire l'Infrastructure

```bash
# ATTENTION : Ceci supprime TOUT !
terraform destroy

# Prévisualiser ce qui sera détruit
terraform plan -destroy
```

### Redémarrage des Services

#### Redémarrer PrestaShop

```bash
# Via SSH sur l'instance EC2
docker restart $(docker ps -q --filter ancestor=prestashop/prestashop)

# Vérifier le redémarrage
docker logs -f $(docker ps -q)
```

#### Redémarrer l'Instance EC2

```bash
# Via AWS CLI
aws ec2 reboot-instances --instance-ids <INSTANCE_ID> --region eu-west-3

# Via Console AWS
# EC2 → Instances → Sélectionner → Actions → Reboot
```

#### Redémarrer RDS (Éviter si possible)

```bash
# Via AWS CLI
aws rds reboot-db-instance --db-instance-identifier prestashop-db --region eu-west-3

# Via Console AWS
# RDS → Databases → Sélectionner → Actions → Reboot
```

---

## Monitoring et Surveillance

### Monitoring AWS CloudWatch

#### Métriques EC2 à Surveiller

1. **CPU Utilization** : doit rester < 70% en moyenne
2. **Network In/Out** : surveillance du trafic
3. **Disk Read/Write** : détection de goulots d'étranglement
4. **Status Checks** : disponibilité de l'instance

#### Métriques RDS à Surveiller

1. **CPU Utilization** : < 80% recommandé
2. **Free Storage Space** : alerter si < 2 GB
3. **Database Connections** : surveiller les connexions actives
4. **Read/Write Latency** : performance de la base de données

#### Configurer des Alarmes CloudWatch

```bash
# Créer une alarme pour CPU EC2 > 80%
aws cloudwatch put-metric-alarm \
  --alarm-name prestashop-high-cpu \
  --alarm-description "Alert when CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=InstanceId,Value=<INSTANCE_ID>
```

### Monitoring Applicatif

#### Vérifications de Santé PrestaShop

```bash
# Script de monitoring simple
#!/bin/bash
# health-check.sh

# Vérifier que PrestaShop répond
if curl -f -s http://localhost > /dev/null; then
    echo "PrestaShop OK"
else
    echo "PrestaShop DOWN"
    # Redémarrer le conteneur
    docker restart $(docker ps -q)
fi
```

#### Surveiller les Performances

```bash
# Temps de réponse de la page d'accueil
curl -o /dev/null -s -w "Temps: %{time_total}s\n" http://localhost

# Vérifier les processus MySQL
docker exec $(docker ps -q) mysql -u root -p<PASSWORD> -e "SHOW PROCESSLIST;"

# Analyser les logs pour les erreurs
docker logs $(docker ps -q) 2>&1 | grep -i error
```

### Logs Centralisés

#### Configuration de Log Rotation

```bash
# Sur l'instance EC2
sudo nano /etc/logrotate.d/docker-containers

# Contenu
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    missingok
    delaycompress
    copytruncate
}
```

---

## Sauvegardes et Restauration

### Stratégie de Sauvegarde

#### Sauvegardes Automatiques RDS

Par défaut, les sauvegardes sont **désactivées** pour rester dans le Free Tier.

**Pour activer les sauvegardes** (coût supplémentaire) :

```hcl
# Dans deploy/main.tf - modifier la ressource aws_db_instance
backup_retention_period = 7  # Garder 7 jours de sauvegardes
backup_window          = "03:00-04:00"  # Fenêtre de sauvegarde
```

Puis :
```bash
terraform apply
```

#### Sauvegardes Manuelles de la Base de Données

```bash
# Se connecter à l'instance EC2
ssh -i ~/.ssh/prestashop_aws ubuntu@<EC2_PUBLIC_IP>

# Créer un dump MySQL
docker exec $(docker ps -q) mysqldump \
  -h <RDS_ENDPOINT> \
  -u prestashop_admin \
  -p<DB_PASSWORD> \
  prestashop > backup_$(date +%Y%m%d).sql

# Compresser le backup
gzip backup_$(date +%Y%m%d).sql

# Télécharger le backup localement
exit  # Quitter SSH
scp -i ~/.ssh/prestashop_aws ubuntu@<EC2_PUBLIC_IP>:backup_*.sql.gz ./backups/
```

#### Sauvegardes des Fichiers PrestaShop

```bash
# Sauvegarder les données du volume Docker
docker run --rm \
  --volumes-from $(docker ps -q) \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/prestashop-files-$(date +%Y%m%d).tar.gz /var/www/html

# Télécharger localement
scp -i ~/.ssh/prestashop_aws ubuntu@<EC2_PUBLIC_IP>:prestashop-files-*.tar.gz ./backups/
```

### Restauration depuis une Sauvegarde

#### Restaurer la Base de Données

```bash
# Uploader le backup vers EC2
scp -i ~/.ssh/prestashop_aws backup_20250107.sql.gz ubuntu@<EC2_PUBLIC_IP>:~

# Se connecter et restaurer
ssh -i ~/.ssh/prestashop_aws ubuntu@<EC2_PUBLIC_IP>
gunzip backup_20250107.sql.gz

docker exec -i $(docker ps -q) mysql \
  -h <RDS_ENDPOINT> \
  -u prestashop_admin \
  -p<DB_PASSWORD> \
  prestashop < backup_20250107.sql
```

#### Restaurer les Fichiers PrestaShop

```bash
# Uploader l'archive
scp -i ~/.ssh/prestashop_aws prestashop-files-20250107.tar.gz ubuntu@<EC2_PUBLIC_IP>:~

# Restaurer
ssh -i ~/.ssh/prestashop_aws ubuntu@<EC2_PUBLIC_IP>
docker run --rm \
  --volumes-from $(docker ps -q) \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/prestashop-files-20250107.tar.gz -C /

# Redémarrer PrestaShop
docker restart $(docker ps -q)
```

### Snapshot d'Instance EC2

```bash
# Créer un snapshot du volume EBS
aws ec2 create-snapshot \
  --volume-id <VOLUME_ID> \
  --description "Backup PrestaShop $(date +%Y%m%d)" \
  --region eu-west-3

# Créer une AMI de l'instance complète
aws ec2 create-image \
  --instance-id <INSTANCE_ID> \
  --name "PrestaShop-Backup-$(date +%Y%m%d)" \
  --description "Full instance backup" \
  --region eu-west-3
```

---

## Dépannage

### Problèmes Courants

#### 1. PrestaShop ne démarre pas

**Symptômes** :
- Le site ne répond pas
- Erreur 502 Bad Gateway

**Diagnostic** :
```bash
# Vérifier que le conteneur tourne
docker ps

# Vérifier les logs
docker logs $(docker ps -q) --tail 100

# Vérifier les ressources
df -h  # Espace disque
free -m  # Mémoire
```

**Solutions** :
```bash
# Redémarrer le conteneur
docker restart $(docker ps -q)

# Si le conteneur est arrêté
docker start $(docker ps -aq)

# Vérifier la connexion à RDS
telnet <RDS_ENDPOINT> 3306
```

#### 2. Erreur de connexion à la base de données

**Symptômes** :
- Message d'erreur "Can't connect to MySQL"
- Page blanche

**Diagnostic** :
```bash
# Vérifier le Security Group RDS
aws ec2 describe-security-groups \
  --group-ids <RDS_SECURITY_GROUP_ID> \
  --region eu-west-3

# Tester la connexion depuis EC2
docker exec -it $(docker ps -q) mysql \
  -h <RDS_ENDPOINT> \
  -u prestashop_admin \
  -p<DB_PASSWORD>
```

**Solutions** :
- Vérifier que le Security Group RDS autorise le trafic depuis EC2
- Vérifier les credentials de base de données
- Vérifier que RDS est en état "available"

#### 3. Instance EC2 inaccessible

**Symptômes** :
- Impossible de se connecter en SSH
- Timeout de connexion

**Diagnostic** :
```bash
# Vérifier l'état de l'instance
aws ec2 describe-instance-status \
  --instance-id <INSTANCE_ID> \
  --region eu-west-3

# Vérifier le Security Group
aws ec2 describe-security-groups \
  --group-ids <SECURITY_GROUP_ID> \
  --region eu-west-3
```

**Solutions** :
- Vérifier que le Security Group autorise le port 22 depuis votre IP
- Vérifier que l'Elastic IP est bien attachée
- Redémarrer l'instance depuis la console AWS

#### 4. Espace disque saturé

**Symptômes** :
- Erreurs d'écriture
- PrestaShop lent ou qui plante

**Diagnostic** :
```bash
# Vérifier l'espace disque
df -h

# Identifier les gros fichiers
du -sh /var/lib/docker/*
docker system df
```

**Solutions** :
```bash
# Nettoyer Docker
docker system prune -a --volumes

# Nettoyer les logs
sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log

# Augmenter le volume EBS si nécessaire
```

#### 5. Performance Dégradée

**Symptômes** :
- Site très lent
- Timeouts fréquents

**Diagnostic** :
```bash
# Vérifier la charge CPU
top

# Vérifier la mémoire
free -m

# Vérifier les requêtes lentes MySQL
docker exec $(docker ps -q) mysql -u root -p<PASSWORD> \
  -e "SHOW PROCESSLIST;"

# Vérifier les métriques CloudWatch
```

**Solutions** :
- Activer le cache PrestaShop
- Optimiser la base de données
- Upgrader le type d'instance (sortir du Free Tier)

### Commandes de Debug Utiles

```bash
# Vérifier la configuration réseau
curl -I http://localhost
netstat -tulpn | grep LISTEN

# Vérifier les variables d'environnement du conteneur
docker exec $(docker ps -q) env

# Exécuter un shell dans le conteneur
docker exec -it $(docker ps -q) /bin/bash

# Vérifier les permissions
docker exec $(docker ps -q) ls -la /var/www/html

# Analyser les logs Apache
docker exec $(docker ps -q) tail -f /var/log/apache2/error.log
```

### Récupération d'Urgence

Si tout échoue :

```bash
# 1. Sauvegarder les données
# (voir section Sauvegardes)

# 2. Détruire et recréer l'infrastructure
cd deploy/
terraform destroy
terraform apply

# 3. Restaurer les données
# (voir section Restauration)
```

---

## Sécurité

### Configuration Initiale de Sécurité

#### 1. Changer les Mots de Passe par Défaut

```bash
# Mot de passe PrestaShop Admin
# Se connecter à l'admin → Paramètres avancés → Équipe → Modifier votre profil

# Mot de passe base de données (déjà fait via terraform.tfvars)
```

#### 2. Sécuriser l'Accès SSH

```bash
# Sur l'instance EC2
sudo nano /etc/ssh/sshd_config

# Modifier :
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes

# Redémarrer SSH
sudo systemctl restart sshd
```

#### 3. Configurer un Pare-feu (UFW)

```bash
# Installer UFW
sudo apt update
sudo apt install ufw

# Configurer les règles
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Activer
sudo ufw enable
```

### Mises à Jour de Sécurité

#### Updates Système Régulières

```bash
# Se connecter à EC2
ssh -i ~/.ssh/prestashop_aws ubuntu@<EC2_PUBLIC_IP>

# Mettre à jour le système
sudo apt update
sudo apt upgrade -y

# Mettre à jour Docker
sudo apt install docker-ce docker-ce-cli containerd.io

# Redémarrer si nécessaire
sudo reboot
```

#### Updates PrestaShop

```bash
# Via l'interface admin
# Admin → Paramètres avancés → Mise à jour

# Ou via Docker (nouvelle version)
docker pull prestashop/prestashop:latest
docker stop $(docker ps -q)
docker rm $(docker ps -aq)
# Relancer avec la nouvelle image
```

### Bonnes Pratiques de Sécurité

1. **Gestion des Credentials**
   - Ne jamais commiter `terraform.tfvars` dans Git
   - Utiliser AWS Secrets Manager pour les secrets en production
   - Rotation régulière des mots de passe (tous les 90 jours)

2. **Restriction d'Accès**
   - Limiter l'accès SSH à des IPs spécifiques
   - Utiliser un bastion host pour les environnements sensibles
   - Activer l'authentification MFA sur AWS

3. **Monitoring de Sécurité**
   - Activer AWS CloudTrail pour l'audit
   - Surveiller les tentatives de connexion SSH : `sudo tail -f /var/log/auth.log`
   - Installer fail2ban : `sudo apt install fail2ban`

4. **Chiffrement**
   - Activer le chiffrement RDS (option dans Terraform)
   - Utiliser HTTPS avec Let's Encrypt (voir section suivante)

### Activer HTTPS avec Let's Encrypt

```bash
# Sur l'instance EC2
sudo apt install certbot python3-certbot-apache

# Obtenir un certificat (nécessite un nom de domaine)
sudo certbot --apache -d votre-domaine.com

# Renouvellement automatique (déjà configuré par défaut)
sudo certbot renew --dry-run
```

---

## Mises à Jour

### Mise à Jour de PrestaShop

#### Via l'Interface Admin

1. Connexion au panneau admin
2. Aller dans **Paramètres avancés** → **Mise à jour**
3. Cliquer sur **Mettre à jour maintenant**
4. Suivre l'assistant de mise à jour

#### Via Docker (Méthode recommandée)

```bash
# Sauvegarder avant la mise à jour !
# (voir section Sauvegardes)

# Se connecter à EC2
ssh -i ~/.ssh/prestashop_aws ubuntu@<EC2_PUBLIC_IP>

# Télécharger la nouvelle image
docker pull prestashop/prestashop:latest

# Arrêter l'ancien conteneur
docker stop $(docker ps -q --filter ancestor=prestashop/prestashop)

# Supprimer l'ancien conteneur (les données restent dans le volume)
docker rm $(docker ps -aq --filter ancestor=prestashop/prestashop)

# Démarrer avec la nouvelle image
docker run -d \
  --name prestashop \
  -e DB_SERVER=<RDS_ENDPOINT> \
  -e DB_NAME=prestashop \
  -e DB_USER=prestashop_admin \
  -e DB_PASSWD=<DB_PASSWORD> \
  -v prestashop-data:/var/www/html \
  -p 80:80 \
  prestashop/prestashop:latest

# Vérifier les logs
docker logs -f prestashop
```

### Mise à Jour de l'Infrastructure Terraform

#### Mise à Jour du Provider AWS

```bash
cd deploy/

# Modifier terraform.tf pour changer la version
nano terraform.tf

# Exemple : passer de 5.92 à 5.93
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.93"
  }
}

# Mettre à jour
terraform init -upgrade
terraform plan
terraform apply
```

#### Scaling Vertical (Changer de Type d'Instance)

```bash
# Modifier terraform.tfvars
INSTANCE_TYPE = "t3.small"  # Au lieu de t2.micro

# Appliquer (va recréer l'instance)
terraform apply

# ATTENTION : Cela va recréer l'instance EC2 !
# Sauvegarder les données avant !
```

### Mise à Jour des Modules et Thèmes PrestaShop

```bash
# Via l'interface admin
# Modules → Module Manager → Mises à jour disponibles

# Ou manuellement
# 1. Télécharger le module/thème
# 2. Uploader via l'interface admin
```

---

## Bonnes Pratiques

### Gestion de l'Infrastructure

1. **Utiliser Git pour Terraform**
   ```bash
   # Toujours commiter les changements
   git add deploy/*.tf
   git commit -m "Update infrastructure configuration"
   git push
   ```

2. **Environnements Séparés**
   - Utiliser des workspaces Terraform pour dev/staging/prod
   ```bash
   terraform workspace new production
   terraform workspace new staging
   terraform workspace select production
   ```

3. **Versioning de l'Infrastructure**
   - Tagger les releases importantes
   ```bash
   git tag -a v1.0.0 -m "Initial production deployment"
   git push origin v1.0.0
   ```

4. **Documentation des Changements**
   - Documenter chaque modification importante
   - Maintenir un changelog

### Gestion des Coûts AWS

1. **Monitoring des Coûts**
   - Activer AWS Cost Explorer
   - Configurer des alertes de budget
   ```bash
   # Créer un budget
   aws budgets create-budget --account-id <ACCOUNT_ID> \
     --budget file://budget.json
   ```

2. **Optimisation Free Tier**
   - Rester sur t2.micro et db.t3.micro
   - Désactiver les sauvegardes RDS automatiques
   - Utiliser un seul environnement

3. **Arrêter les Ressources Non Utilisées**
   ```bash
   # Arrêter l'instance EC2 la nuit (économie hors Free Tier)
   aws ec2 stop-instances --instance-ids <INSTANCE_ID>

   # Redémarrer le matin
   aws ec2 start-instances --instance-ids <INSTANCE_ID>
   ```

### Performance et Optimisation

1. **Cache PrestaShop**
   - Activer le cache dans l'admin
   - Admin → Paramètres avancés → Performances

2. **Optimisation Base de Données**
   ```bash
   # Optimiser les tables régulièrement
   docker exec $(docker ps -q) mysql -u root -p<PASSWORD> \
     -e "OPTIMIZE TABLE prestashop.*;"
   ```

3. **CDN pour les Assets Statiques**
   - Utiliser CloudFront pour servir les images/CSS/JS
   - Réduire la charge sur EC2

4. **Monitoring Continu**
   - Surveiller les métriques CloudWatch
   - Ajuster les ressources selon la charge

### Disaster Recovery

1. **Plan de Reprise d'Activité**
   - Sauvegardes régulières (quotidiennes minimum)
   - Tests de restauration mensuels
   - Documentation des procédures de récupération

2. **RTO/RPO Objectives**
   - **RTO** (Recovery Time Objective) : 4 heures maximum
   - **RPO** (Recovery Point Objective) : 24 heures maximum

3. **Checklist de Récupération**
   - [ ] Identifier la cause de la panne
   - [ ] Communiquer aux parties prenantes
   - [ ] Restaurer depuis la dernière sauvegarde
   - [ ] Vérifier l'intégrité des données
   - [ ] Tester le fonctionnement complet
   - [ ] Documenter l'incident

---

## Annexes

### Checklist de Déploiement Initial

- [ ] Prérequis installés (Docker, Terraform, Git)
- [ ] Repository cloné
- [ ] Compte AWS créé
- [ ] Utilisateur IAM avec permissions créé
- [ ] Paire de clés SSH générée
- [ ] `terraform.tfvars` configuré avec credentials
- [ ] Mot de passe base de données fort défini
- [ ] `terraform init` exécuté avec succès
- [ ] `terraform plan` vérifié
- [ ] `terraform apply` exécuté
- [ ] Outputs Terraform sauvegardés
- [ ] Connexion SSH à EC2 testée
- [ ] PrestaShop accessible via navigateur
- [ ] Panneau admin accessible
- [ ] Mot de passe admin changé
- [ ] Sauvegarde initiale effectuée
- [ ] Monitoring CloudWatch configuré
- [ ] Alarmes configurées

### Checklist de Maintenance Mensuelle

- [ ] Vérifier les mises à jour système sur EC2
- [ ] Vérifier les mises à jour PrestaShop disponibles
- [ ] Tester la restauration d'une sauvegarde
- [ ] Analyser les logs pour anomalies
- [ ] Vérifier les métriques CloudWatch
- [ ] Optimiser la base de données
- [ ] Nettoyer les fichiers temporaires
- [ ] Vérifier l'espace disque disponible
- [ ] Vérifier les coûts AWS
- [ ] Mettre à jour la documentation si nécessaire

### Contacts et Ressources Utiles

#### Documentation Officielle

- **PrestaShop** : https://devdocs.prestashop.com/
- **Terraform AWS Provider** : https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **Docker** : https://docs.docker.com/
- **AWS EC2** : https://docs.aws.amazon.com/ec2/
- **AWS RDS** : https://docs.aws.amazon.com/rds/

#### Support

- **Forum PrestaShop** : https://www.prestashop.com/forums/
- **AWS Support** : https://console.aws.amazon.com/support/

---

## Changelog

### Version 1.0.0 - 2025-01-07
- Version initiale du guide de déploiement
- Documentation complète pour Docker Compose et Terraform
- Procédures de maintenance et dépannage
- Bonnes pratiques de sécurité et performance

---

**Dernière mise à jour** : 2025-01-07

**Version** : 1.0.0
