# PrestaShop AWS

Déploiement de PrestaShop sur AWS avec infrastructure **Free Tier** (gratuit pendant 12 mois).

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

## Déploiement AWS (Free Tier)

L'infrastructure Terraform utilise des ressources **gratuites** pendant 12 mois :
- **EC2 t2.micro** (750h/mois gratuit)
- **RDS db.t3.micro** (750h/mois gratuit)
- **20GB stockage** (gratuit)

### Commandes Terraform

Toutes les commandes doivent être exécutées depuis le dossier `deploy/`:

```bash
cd deploy/

# Configuration initiale
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars avec vos identifiants AWS

# Initialisation
terraform init

# Formattage
terraform fmt

# Validation
terraform validate

# Prévisualiser les changements
terraform plan

# Création de l'infrastructure
terraform apply

# Inspecter l'état actuel de l'infrastructure
terraform state list

# Détruire l'infrastructure
terraform destroy
```

**Documentation complète:** Voir `deploy/README.md` pour les instructions détaillées.

## Coût Estimé

- **Première année:** GRATUIT (AWS Free Tier)
- **Après 12 mois:** ~$25/mois (avec instances Free Tier)
- **Production (instances plus grandes):** ~$55/mois