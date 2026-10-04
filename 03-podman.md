# Chapitre 05 — Gérer les conteneurs avec Podman

> **Objectif :** apprendre à gérer des conteneurs avec Podman et être capable de réaliser des tâches pratiques de type: lancement de conteneurs, port mapping, volumes, copie de fichiers, variables d'environnement, construction d'images avec `Containerfile`, réseaux et déploiements multi-conteneurs.
<p align="center">

<img src=images/podman-logo.png width=300>
</p>
---
## 0. Introduction à Podman

Podman utilise une interface de commandes très proche de Docker :

```bash
podman run
podman ps
podman exec
podman cp
podman build
podman network
podman volume
```

Dans ce chapitre, on se concentre sur les commandes utiles pour administrer des applications conteneurisées.

---

# 1. Construire une image avec un `Containerfile`

Instructions importantes:

| Instruction | Rôle |
|---|---|
| `FROM` | Image de base |
| `ARG` | Variable disponible pendant le build |
| `ENV` | Variable d'environnement |
| `RUN` | Exécuter une commande pendant le build |
| `COPY` | Copier des fichiers dans l'image |
| `WORKDIR` | Définir le répertoire de travail |
| `EXPOSE` | Documenter un port utilisé par l'application |
| `CMD` | Commande par défaut |
| `ENTRYPOINT` | Programme principal du conteneur |

> `EXPOSE 80` **ne publie pas** le port sur l'hôte. Pour publier le port, il faut utiliser `-p`, par exemple `-p 8080:80`.

Un `Containerfile` décrit comment construire une image.

Exemple :

```Dockerfile
FROM docker.io/library/alpine:latest

RUN apk add --no-cache nginx

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

Construire :

```bash
podman build -t custom-nginx .
```

Lancer :

```bash
podman run -d --name custom-nginx -p 8080:80 custom-nginx
```

---

# 2. Lancer un conteneur

La commande principale est :

```bash
podman run [OPTIONS] IMAGE
```

Exemple :

```bash
podman run -d --name web nginx
```

### Options importantes

| Option | Rôle |
|---|---|
| `-d` | Exécuter en arrière-plan (detached) |
| `--name` | Donner un nom au conteneur |
| `-p` | Publier un port |
| `-v` | Monter un volume ou un répertoire |
| `-e` | Définir une variable d'environnement |
| `--network` | Connecter le conteneur à un réseau |
| `--rm` | Supprimer le conteneur à son arrêt |

Vérifier les conteneurs :

```bash
podman ps
```

Afficher également les conteneurs arrêtés :

```bash
podman ps -a
```

---

# 3. Port Mapping

## 3.1 Principe

Un processus qui écoute dans un conteneur n'est pas automatiquement accessible sur un port de l'hôte.

On utilise :

```bash
-p HOST_PORT:CONTAINER_PORT
```

Exemple :

```bash
podman run -d \
  --name nginx \
  -p 8001:80 \
  nginx
```

Le mapping signifie :

```text
Host                         Container
┌───────────────┐            ┌───────────────┐
│ Port 8001     │ ─────────> │ Port 80       │
│               │            │ nginx         │
└───────────────┘            └───────────────┘
```

On accède alors à Nginx avec :

```bash
curl http://localhost:8001
```

### À retenir

```text
-p 8001:80
   │    │
   │    └── port dans le conteneur
   └─────── port sur l'hôte
```

> **Conseil examen :** toujours lire `HOST:CONTAINER` et non l'inverse.

---

# 4. Volumes avec `-v`

Les conteneurs sont éphémères par nature. Si les données importantes restent uniquement dans le filesystem du conteneur, elles peuvent être perdues lorsque le conteneur est supprimé.

Les volumes permettent de conserver ou de partager des données indépendamment du cycle de vie du conteneur.

La syntaxe générale est :

```bash
-v SOURCE:DESTINATION
```

Exemple :

```bash
-v /home/student/web:/usr/share/nginx/html
```

Cela signifie :

```text
Host
/home/student/web
       │
       │ mount
       ▼
Container
/usr/share/nginx/html
```

---

# 5. Les principaux types de montages

Avec Podman, on rencontre principalement trois cas pratiques.

## 5.1 Bind mount

On monte un répertoire ou un fichier existant de l'hôte.

Syntaxe :

```bash
-v HOST_PATH:CONTAINER_PATH
```

Exemple :

```bash
podman run -d \
  --name nginx \
  -v "$HOME/site:/usr/share/nginx/html:Z" \
  nginx
```

Ici :

```text
$HOME/site
     ↓
/usr/share/nginx/html
```

Le contenu du répertoire de l'hôte est directement accessible dans le conteneur.

#### Pourquoi :Z?
un système avec SELinux, le fichier du volume possède un contexte de sécurité que le processus du conteneur doit être autorisé à utiliser.
Par exemple, sans :Z :
```text
-v $HOME/site:/usr/share/nginx/html
```
SELinux peut empêcher Nginx dans le conteneur d'accéder aux fichiers, même si les permissions Linux classiques (chmod, chown) semblent correctes.
Avec :
```text
-v $HOME/site:/usr/share/nginx/html:Z
```
Podman relabellise les fichiers avec un contexte SELinux approprié pour le conteneur, ce qui permet au processus du conteneur d'y accéder.
À retenir : :Z ne sert pas à donner des permissions Linux classiques ; il sert à adapter les permissions de sécurité SELinux pour que le conteneur puisse accéder au volume.
#### Différence entre :Z et :z?
`:Z` : attribue au volume un contexte SELinux privé, destiné à être utilisé par un seul conteneur.
`:z` : attribue au volume un contexte SELinux partagé, **permettant à plusieurs conteneurs d'utiliser le même contenu.**
par exemple:

```text
podman run -d --name app1 -v "$HOME/shared-data:/data:z" nginx
podman run -d --name app2 -v "$HOME/shared-data:/data:z" nginx
```

### Quand 'utiliser ce mount?

- développement ;
- configuration ;
- partage de fichiers ;
- contenu web ;
- scripts ;
- données que l'administrateur souhaite gérer directement depuis l'hôte.

---

## 5.2 Named volume

Podman peut créer un volume géré par Podman.

Créer le volume :

```bash
podman volume create host-data
```

Vérifier :

```bash
podman volume ls
```

Monter le volume :

```bash
podman run -d --name app -v host-data:/data nginx
```

Le volume est identifié par son nom :

```text
host-data
     │
     ▼
/data
```

Le stockage physique est géré par Podman.

### Quand l'utiliser ?

Les named volumes sont particulièrement pratiques pour :

- bases de données ;
- données persistantes ;
- applications qui doivent conserver leurs données ;
- partage de données entre plusieurs conteneurs.

---

## 5.3 Anonymous volume

Il est également possible de demander à Podman de créer un volume sans lui donner explicitement un nom :

```bash
podman run -d --name app -v /data nginx
```

Podman crée alors un volume associé au conteneur.

Pour afficher les volumes :

```bash
podman volume ls
```

### À retenir

```text
Bind mount
-v /home/student/data:/data

Named volume
-v acme-data:/data

Anonymous volume
-v /data
```

---
# 6. Copier des fichiers avec `podman cp`

La commande :

```bash
podman cp
```

permet de copier des fichiers ou répertoires :

```text
Host → Container
Container → Host
```

## 6.1 Host → Container

Syntaxe :

```bash
podman cp SOURCE CONTAINER:DESTINATION
```

Exemple :

```bash
podman cp index.html nginx:/usr/share/nginx/html/index.html
```

---

## 6.2 Container → Host

Syntaxe :

```bash
podman cp CONTAINER:SOURCE DESTINATION
```

Exemple :

```bash
podman cp nginx:/etc/nginx/nginx.conf ./nginx.conf
```

---

## 6.3 Copier un répertoire

Exemple :

```bash
podman cp "$HOME/workspace2/acme-nginx-web/html/." acme-demo-nginx:/usr/share/nginx/html/
```

Le `/.` est utile lorsque l'on souhaite copier **le contenu** du répertoire plutôt que créer un sous-répertoire `html` dans la destination.

# 8. Variables d'environnement

Une variable d'environnement permet de transmettre une configuration au processus exécuté dans le conteneur.

Avec Podman :

```bash
-e NAME=value
```

Exemple :

```bash
podman run -d --name app -e RESPONSE="Hello ACME" quay.io/myacme/welcome
```

À l'intérieur du conteneur :

```bash
echo "$RESPONSE"
```

donnera :

```text
Hello ACME
```

---

# 9. `ARG` vs `ENV`

C'est une distinction très importante lors de la construction d'une image.

## 10.1 `ARG`

`ARG` définit une variable utilisée **pendant le build de l'image**.

Exemple :

```Dockerfile
FROM docker.io/library/alpine:latest

ARG APP_VERSION

RUN echo "Building version $APP_VERSION"
```

Construction :

```bash
podman build --build-arg APP_VERSION=1.0 -t acme-app:1.0 .
```

L'argument est fourni au moment du :

```bash
podman build
```

---

## 10.2 `ENV`

`ENV` définit une variable d'environnement disponible dans l'image et lors de l'exécution du conteneur.

Exemple :

```Dockerfile
FROM docker.io/library/alpine:latest

ENV APP_VERSION=1.0

CMD ["sh", "-c", "echo Version=$APP_VERSION"]
```

Construire :

```bash
podman build -t acme-app .
```

Puis :

```bash
podman run --rm acme-app
```

Résultat :

```text
Version=1.0
```

---

# 11. Différence entre `ARG` et `ENV`

| | `ARG` | `ENV` |
|---|---|---|
| Utilisation principale | Build | Runtime |
| Fourni avec | `--build-arg` | `-e` ou `ENV` |
| Disponible pendant le build | Oui | Oui |
| Disponible dans le conteneur | Pas automatiquement | Oui |
| Exemple | version de build | configuration de l'application |

> **Attention :** ne pas utiliser `ARG` comme mécanisme de stockage de secrets. Les valeurs utilisées pendant un build peuvent être exposées dans l'historique ou les métadonnées de l'image.

---

# 12. Exemple `ARG` → `ENV`

Un cas très fréquent consiste à utiliser un argument de build pour définir une valeur dans l'environnement final.

### Containerfile

```Dockerfile
FROM docker.io/library/mariadb:latest

ARG ACME_MARIADB_DATABASE
ARG ACME_MARIADB_PASSWORD

ENV MARIADB_DATABASE=${ACME_MARIADB_DATABASE}
ENV MARIADB_ROOT_PASSWORD=${ACME_MARIADB_PASSWORD}
```

Build :

```bash
podman build \
  --build-arg ACME_MARIADB_DATABASE=acme \
  --build-arg ACME_MARIADB_PASSWORD=acme \
  -t acme:5000/acme-mariadb:latest .
```
---

# 13. Les réseaux Podman

Les applications multi-conteneurs ont généralement besoin de communiquer entre elles.

Alors:

On peut créer un réseau :

```bash
podman network create net
```

Vérifier :

```bash
podman network ls
```

Pourquoi mettre les conteneurs sur le même réseau ?

Prenons une application :

```text
WordPress
    │
    ▼
MariaDB
```

WordPress doit contacter MariaDB.

Si les deux conteneurs sont connectés au même réseau Podman, ils peuvent communiquer via le réseau interne et utiliser le nom du conteneur comme nom logique.

Exemple :

```bash
podman run -d --name mariadb --network net mariadb
```

Puis :

```bash
podman run -d --name wordpress --network net wordpress
```

L'application WordPress peut alors utiliser :

```text
mariadb
```

comme hostname de la base de données.

Pourquoi ne pas utiliser `localhost` ?

Dans un conteneur :

```text
localhost
```

désigne **le conteneur lui-même**, pas un autre conteneur.

Donc dans WordPress :

```text
DB_HOST=localhost
```

signifierait :

```text
WordPress → lui-même
```

alors que :

```text
DB_HOST=mariadb
```

signifie :

```text
WordPress → MariaDB
```

# 14. Autres commandes essentielles à connaître

## Conteneurs

```bash
podman ps
podman ps -a
podman run
podman start
podman stop
podman restart
podman rm
podman inspect
podman logs
podman exec
podman cp
```

## Images

```bash
podman images
podman pull
podman build
podman rmi
podman inspect
```

## Volumes

```bash
podman volume create
podman volume ls
podman volume inspect
podman volume rm
```

## Réseaux

```bash
podman network create
podman network ls
podman network inspect
podman network connect
podman network disconnect
podman network rm
```

---


# 15. Questions de compréhension

1. Quelle est la différence entre un port du conteneur et un port de l'hôte ?
2. Que signifie `-p 8001:80` ?
3. Pourquoi `EXPOSE 80` ne suffit-il pas pour accéder à Nginx depuis l'hôte ?
4. Quelle est la différence entre un bind mount et un named volume ?
5. Pourquoi utiliser un volume pour une base de données ?
6. Quelle est la différence entre `podman cp` et `-v` ?
7. Dans quel sens fonctionne `podman cp` ?
8. Quelle est la différence entre `ARG` et `ENV` ?
9. Quand utilise-t-on `--build-arg` ?
10. Quand utilise-t-on `-e` ?
11. Pourquoi ne faut-il pas utiliser `ARG` pour stocker des secrets ?
12. Pourquoi deux conteneurs ne peuvent-ils pas publier simultanément le même port de l'hôte ?
13. Pourquoi WordPress et MariaDB doivent-ils être sur le même réseau ?
14. Pourquoi `localhost` ne permet-il pas à WordPress de joindre MariaDB ?
15. Quel est le rôle de `podman network inspect` ?
16. Quel est le rôle de `podman volume inspect` ?
17. Comment vérifier les logs d'un conteneur ?
18. Comment entrer dans un conteneur en cours d'exécution ?
19. Quelle est la différence entre `podman stop` et `podman rm` ?
20. Quelle est la différence entre une image et un conteneur ?