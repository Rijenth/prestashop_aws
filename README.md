# PrestaShop AWS

## Accès à la plateforme

### Frontend (Boutique)

http://localhost:8080

### Administration

http://localhost:8080/admin-dev

**Identifiants**

***Email:***
```
demo@prestashop.com
```

***Mot de passe:***
```
prestashop_demo
```

## Gestion de l'infrastructure

### Démarrer les services
```bash
docker-compose up -d --build
```

### Arrêt des services
```bash
docker-compose down
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
