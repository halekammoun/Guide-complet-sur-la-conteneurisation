# 01 --- Construire un conteneur manuellement

> **How Linux Containers Actually Work**

Ce chapitre constitue le point de départ du **Guide complet sur la
conteneurisation**.\
L'objectif n'est pas seulement d'apprendre à lancer un conteneur, mais
de comprendre les mécanismes Linux qui permettent à un runtime comme
`runc`, `containerd`, Docker ou Podman de construire et d'exécuter un
conteneur.

> **Idée clé :** un conteneur n'est pas une machine virtuelle. C'est
> essentiellement un ou plusieurs processus Linux isolés et limités par
> le noyau Linux.

------------------------------------------------------------------------

## Table des matières

1.  [Objectifs](#1-objectifs)
2.  [Qu'est-ce qu'un conteneur ?](#2-quest-ce-quun-conteneur)
3.  [Conteneur vs machine virtuelle](#3-conteneur-vs-machine-virtuelle)
4.  [Ce que Docker fait sous le
    capot](#4-ce-que-docker-fait-sous-le-capot)
5.  [Les processus Linux](#5-les-processus-linux)
6.  [`fork()` et `exec()`](#6-fork-et-exec)
7.  [Le système `/proc`](#7-le-système-proc)
8.  [Le root filesystem](#8-le-root-filesystem)
9.  [`mount` et les bind mounts](#9-mount-et-les-bind-mounts)
10. [`chroot`](#10-chroot)
11. [`pivot_root`](#11-pivot_root)
12. [Les Linux namespaces](#12-les-linux-namespaces)
13. [PID namespace](#13-pid-namespace)
14. [Network namespace](#14-network-namespace)
15. [Mount namespace](#15-mount-namespace)
16. [UTS namespace](#16-uts-namespace)
17. [IPC namespace](#17-ipc-namespace)
18. [User namespace](#18-user-namespace)
19. [Namespaces : isolation de la
    visibilité](#19-namespaces--isolation-de-la-visibilité)
20. [Les Linux cgroups](#20-les-linux-cgroups)
21. [Namespaces vs cgroups](#21-namespaces-vs-cgroups)
22. [`unshare`, `clone()` et `setns()`](#22-unshare-clone-et-setns)
23. [Construire un mini-conteneur sans
    Docker](#23-construire-un-mini-conteneur-sans-docker)
24. [Observer et vérifier le
    conteneur](#24-observer-et-vérifier-le-conteneur)
25. [Relier le mini-conteneur à runc, containerd et
    Docker](#25-relier-le-mini-conteneur-à-runc-containerd-et-docker)
26. [Résumé](#26-résumé)
27. [Travaux pratiques](#27-travaux-pratiques)
28. [Questions de compréhension](#28-questions-de-compréhension)

------------------------------------------------------------------------

# 1. Objectifs

À la fin de ce chapitre, vous serez capable de :

-   expliquer ce qu'est réellement un conteneur Linux ;
-   distinguer conteneur et machine virtuelle ;
-   comprendre le cycle de vie élémentaire d'un processus Linux ;
-   expliquer le rôle de `fork()` et `exec()` ;
-   utiliser `/proc` pour observer les processus ;
-   comprendre le rôle d'un `rootfs` ;
-   expliquer `mount`, bind mount, `chroot` et `pivot_root` ;
-   expliquer les principaux Linux namespaces ;
-   créer et observer des namespaces avec `unshare` ;
-   comprendre le rôle des cgroups ;
-   limiter CPU, mémoire, PIDs et autres ressources ;
-   comprendre les rôles de `clone()`, `unshare()` et `setns()` ;
-   construire un mini-conteneur Linux sans Docker ;
-   comprendre quelles opérations un runtime OCI automatise ;
-   relier ces primitives Linux à `runc`, `containerd`, Docker et
    Podman.

------------------------------------------------------------------------

# 2. Qu'est-ce qu'un conteneur ?

Un conteneur est un environnement d'exécution dans lequel un ou
plusieurs processus Linux disposent d'une **vue isolée du système** et
peuvent être soumis à des **limites de ressources**.

Un conteneur ne démarre pas un noyau Linux séparé.

Le processus du conteneur s'exécute directement sur le noyau de l'hôte :

``` text
                Linux Kernel
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
   Processus A   Processus B   Container
                                │
                                ├── namespaces
                                ├── cgroups
                                └── rootfs
```

La différence fondamentale avec une VM est donc l'utilisation d'un
**noyau partagé**.

### Phrase clé

> **A container is an isolated and resource-controlled Linux process
> environment, not a separate operating system.**

------------------------------------------------------------------------

# 3. Conteneur vs machine virtuelle

## Machine virtuelle

Une machine virtuelle possède généralement :

``` text
Application
    │
Guest OS
    │
Virtual Hardware
    │
Hypervisor
    │
Host OS / Hardware
```

Chaque VM possède son propre système d'exploitation invité et son propre
noyau.

## Conteneur

Un conteneur fonctionne plutôt ainsi :

``` text
Application
    │
Container filesystem
    │
Linux process
    │
Linux Kernel
    │
Hardware
```

Plusieurs conteneurs utilisent donc le même noyau Linux.

### Comparaison

  Élément           Machine virtuelle              Conteneur
  ----------------- ------------------------------ ----------------------------
  Noyau             Généralement propre au guest   Partagé avec l'hôte
  Isolation         Forte, niveau machine          Niveau processus / kernel
  Démarrage         Plus lourd                     Généralement très rapide
  Ressources        Plus importantes               Plus légères
  Root filesystem   OS complet                     Filesystem de l'image
  Runtime           Hyperviseur                    Runtime de conteneur
  Exemple           KVM, VMware                    Docker, Podman, containerd

------------------------------------------------------------------------

# 4. Ce que Docker fait sous le capot

Lorsque vous exécutez :

``` bash
docker run -it ubuntu bash
```

vous voyez une seule commande.

Pourtant, de nombreuses opérations sont réalisées derrière cette
abstraction.

Une représentation simplifiée est :

``` text
                     Docker CLI
                         │
                         ▼
                   Docker Engine
                         │
                         ▼
                      containerd
                         │
                         ▼
                    OCI Runtime
                    runc / crun
                         │
                         ▼
                    Linux Kernel
             ┌───────────┼───────────┐
             ▼           ▼           ▼
        Namespaces     cgroups    Filesystem
             │           │           │
             ▼           ▼           ▼
         Isolation    Resources     rootfs
```

Docker automatise donc énormément de choses que nous allons effectuer
manuellement dans ce chapitre.

## Docker exploite les mécanismes Linux

  -----------------------------------------------------------------------
  Primitive Linux                     Rôle dans la conteneurisation
  ----------------------------------- -----------------------------------
  `fork()` / `exec()`                 Création et exécution des processus

  `/proc`                             Observation des processus

  `mount`                             Montage des systèmes de fichiers

  Bind mount                          Montage d'un répertoire existant
                                      dans un autre emplacement

  `chroot`                            Modification de la racine visible
                                      d'un processus

  `pivot_root`                        Changement de root filesystem dans
                                      un environnement monté

  PID namespace                       Isolation des identifiants de
                                      processus

  Network namespace                   Isolation du réseau

  Mount namespace                     Isolation des points de montage

  UTS namespace                       Isolation du hostname et du domain
                                      name

  IPC namespace                       Isolation des mécanismes IPC

  User namespace                      Isolation / mapping des UID et GID

  cgroups                             Contrôle des ressources

  `clone()`                           Création de processus avec
                                      isolation

  `unshare()`                         Séparation d'un processus d'un
                                      namespace

  `setns()`                           Entrée dans un namespace existant
  -----------------------------------------------------------------------

> **Docker ne remplace pas ces mécanismes. Il les exploite et les
> automatise.**

------------------------------------------------------------------------

# 5. Les processus Linux

Avant de construire un conteneur, il faut comprendre ce que nous allons
isoler : **un processus Linux**.

Un processus est une instance en cours d'exécution d'un programme.

Sur Linux, chaque processus possède notamment :

-   un PID ;
-   un PPID ;
-   un espace mémoire ;
-   des descripteurs de fichiers ;
-   un environnement ;
-   un répertoire de travail ;
-   des credentials ;
-   des namespaces auxquels il appartient ;
-   éventuellement un groupe de contrôle (cgroup).

## Observer les processus

``` bash
ps aux
```

ou :

``` bash
ps -ef
```

Pour observer l'arbre :

``` bash
pstree
```

Pour afficher les processus dynamiquement :

``` bash
top
```

Un système Linux classique peut présenter :

``` text
PID  COMMAND
1    systemd
...
1250 sshd
...
4300 dockerd
...
5000 containerd
...
7000 bash
```

------------------------------------------------------------------------

# 6. `fork()` et `exec()`

Deux concepts sont fondamentaux pour comprendre le lancement des
programmes Linux : `fork()` et `exec()`.

## `fork()`

`fork()` crée un nouveau processus à partir d'un processus existant.

Conceptuellement :

``` text
             processus parent
                    │
                  fork()
                    │
                    ▼
             processus enfant
```

Le processus enfant reçoit un nouvel identifiant de processus.

## `exec()`

`exec()` remplace le programme exécuté par un processus par un autre
programme.

Conceptuellement :

``` text
processus enfant
      │
    exec()
      │
      ▼
nouveau programme
```

On peut donc simplifier :

``` text
processus parent
       │
       │ fork()
       ▼
processus enfant
       │
       │ exec()
       ▼
nouveau programme
```

### Important

Il ne faut pas résumer le fonctionnement d'un runtime de conteneurs à :

> Docker fait simplement `fork()` puis `exec()`.

Un runtime de conteneur doit également créer/configurer des namespaces,
des mounts, des cgroups, un root filesystem, des credentials et d'autres
éléments de l'environnement d'exécution.

Des primitives comme `clone()` sont particulièrement importantes pour la
création de processus avec des namespaces.

------------------------------------------------------------------------

# 7. Le système `/proc`

`/proc` est un filesystem virtuel fourni par le noyau Linux.

Il expose de nombreuses informations sur les processus et le système.

Par exemple :

``` bash
ls /proc
```

Les répertoires numériques correspondent généralement à des PID :

``` text
/proc/1
/proc/2
/proc/100
...
```

Pour observer le processus courant :

``` bash
echo $$
```

Puis :

``` bash
ls /proc/$$
```

Quelques fichiers utiles :

``` bash
cat /proc/$$/status
cat /proc/$$/cmdline
cat /proc/$$/mounts
```

Le répertoire :

``` bash
/proc/<PID>/ns/
```

permet notamment d'observer les namespaces auxquels appartient un
processus.

Exemple :

``` bash
ls -l /proc/1/ns/
```

Vous pouvez comparer les namespaces de deux processus :

``` bash
ls -l /proc/1/ns/
ls -l /proc/$$/ns/
```

Deux processus qui affichent le même inode de namespace appartiennent au
même namespace correspondant.

------------------------------------------------------------------------

# 8. Le root filesystem

Un processus Linux utilise un système de fichiers pour accéder à :

``` text
/
/bin
/etc
/usr
/var
/dev
/proc
/sys
...
```

Dans un conteneur, le processus doit recevoir une **vue filesystem
adaptée**.

On parle de `rootfs` ou root filesystem.

Un rootfs minimal peut ressembler à :

``` text
rootfs/
├── bin/
├── etc/
├── lib/
├── lib64/
├── proc/
├── sys/
├── dev/
├── tmp/
├── usr/
└── var/
```

Dans une image de conteneur, le rootfs provient généralement des layers
de l'image.

Conceptuellement :

``` text
Image
 │
 ├── Layer 1
 ├── Layer 2
 ├── Layer 3
 └── Layer 4
       │
       ▼
 merged filesystem
       │
       ▼
     rootfs
```

Le conteneur voit ensuite une arborescence telle que :

``` text
/
├── bin
├── etc
├── usr
├── var
└── ...
```

------------------------------------------------------------------------

# 9. `mount` et les bind mounts

La commande `mount` permet d'attacher un filesystem à un point de
montage.

Exemple :

``` bash
mount
```

Pour créer un bind mount :

``` bash
mount --bind /source /destination
```

Le bind mount rend un répertoire existant accessible à un autre
emplacement.

Exemple :

``` bash
mkdir -p /tmp/source
mkdir -p /tmp/destination

mount --bind /tmp/source /tmp/destination
```

Dans les conteneurs, les mécanismes de montage sont importants pour
construire la vue filesystem du processus.

> Les volumes et bind mounts proposés par les outils de conteneurs
> reposent sur les mécanismes de montage Linux.

------------------------------------------------------------------------

# 10. `chroot`

`chroot` permet de changer le répertoire considéré comme racine (`/`)
pour un processus.

Exemple :

``` bash
chroot /path/to/rootfs /bin/bash
```

Le processus voit alors `/path/to/rootfs` comme `/`.

## Exemple conceptuel

Avant :

``` text
Host
├── /bin
├── /etc
├── /home
└── /var
```

Après `chroot` :

``` text
Rootfs
├── /bin
├── /etc
├── /home
└── /var
```

### Attention

`chroot` ne constitue pas à lui seul une isolation moderne complète des
conteneurs.

Il ne fournit pas :

-   un PID namespace ;
-   un network namespace ;
-   des cgroups ;
-   une isolation complète des utilisateurs ;
-   une isolation complète des mounts.

Il est donc préférable de le présenter comme un mécanisme **historique /
basique d'isolation du filesystem**, utile pédagogiquement.

Les conteneurs modernes combinent plutôt plusieurs primitives Linux.

------------------------------------------------------------------------

# 11. `pivot_root`

`pivot_root` permet de remplacer le root filesystem d'un processus par
un autre root filesystem.

Conceptuellement :

``` text
Ancien root
     │
     │ pivot_root()
     ▼
Nouveau rootfs
     │
     ▼
Processus du conteneur
```

C'est particulièrement pertinent dans la construction d'un environnement
de conteneur, avec les mount namespaces.

> Selon les implémentations modernes, d'autres mécanismes peuvent être
> utilisés pour obtenir un résultat équivalent. L'objectif pédagogique
> est de comprendre comment un processus peut être placé dans une
> nouvelle vue du filesystem.

------------------------------------------------------------------------

# 12. Les Linux namespaces

Les namespaces sont l'un des mécanismes les plus importants de la
conteneurisation Linux.

Ils permettent de donner à un processus une **vue isolée d'une partie du
système**.

On peut représenter le principe ainsi :

``` text
                         Linux Kernel
                              │
             ┌────────────────┼────────────────┐
             │                │                │
             ▼                ▼                ▼
        Host namespace   Container A       Container B
                              │
                              ├── PID
                              ├── NET
                              ├── MNT
                              ├── UTS
                              ├── IPC
                              └── USER
```

Chaque namespace fournit une vue différente d'une ressource système.

## Les principaux namespaces étudiés

  Namespace   Fonction
  ----------- ---------------------------------
  PID         Isolation des processus
  NET         Isolation réseau
  MNT         Isolation des mounts
  UTS         Isolation du hostname
  IPC         Isolation des mécanismes IPC
  USER        Isolation / mapping des UID/GID

------------------------------------------------------------------------

# 13. PID namespace

Le PID namespace isole la visibilité des processus.

Sur l'hôte :

``` text
PID 1    systemd
PID 1250 sshd
PID 4300 dockerd
PID 5000 containerd
PID 7000 bash
```

Dans un conteneur, le même environnement peut présenter :

``` text
PID 1    bash
PID 2    nginx
PID 3    ...
```

Le processus peut donc avoir une vue différente de l'arbre des
processus.

## Pourquoi PID 1 est important ?

Le premier processus du PID namespace reçoit généralement le PID `1`
dans ce namespace.

Dans un conteneur :

``` text
PID 1
 │
 ├── application
 └── child processes
```

Le comportement du PID 1 est donc important pour la gestion des
processus et des signaux dans le conteneur.

------------------------------------------------------------------------

# 14. Network namespace

Le network namespace fournit une vue isolée de la configuration réseau.

Un network namespace peut posséder :

``` text
Interfaces
IP addresses
Routing table
iptables / networking state
Sockets
```

Par exemple :

``` text
Container network namespace

lo
eth0
routes
IP addresses
```

Le conteneur peut recevoir une adresse telle que :

``` text
172.x.x.x
```

Cette interface n'est pas simplement la même interface réseau que celle
directement utilisée par l'hôte.

Les mécanismes comme `veth` et les bridges Linux permettent ensuite de
connecter ce namespace au réseau de l'hôte.

Le réseau sera étudié en profondeur dans le chapitre dédié au networking
et à CNI.

------------------------------------------------------------------------

# 15. Mount namespace

Le mount namespace isole la vue des points de montage.

On peut avoir :

``` text
Host
├── /proc
├── /sys
├── /dev
└── /data

Container
├── /proc
├── /sys
├── /dev
└── /data
```

Les deux environnements peuvent toutefois avoir des ensembles de mounts
différents.

Pour observer les mounts :

``` bash
findmnt
```

ou :

``` bash
cat /proc/self/mountinfo
```

Le mount namespace est essentiel pour construire le root filesystem et
isoler la vue filesystem du conteneur.

------------------------------------------------------------------------

# 16. UTS namespace

Le UTS namespace permet notamment d'avoir un hostname différent.

Sur l'hôte :

``` text
server01
```

Dans un conteneur :

``` text
web-container
```

Pour observer :

``` bash
hostname
```

Avec un UTS namespace, le processus peut donc avoir son propre hostname
sans modifier celui de l'hôte.

------------------------------------------------------------------------

# 17. IPC namespace

IPC signifie **Inter-Process Communication**.

Le namespace IPC isole certains mécanismes de communication
inter-processus, notamment :

-   System V IPC ;
-   POSIX message queues.

L'objectif est d'empêcher les processus appartenant à différents
environnements isolés de partager automatiquement certaines ressources
IPC.

------------------------------------------------------------------------

# 18. User namespace

Le user namespace permet d'isoler les identités utilisateurs et groupes.

C'est particulièrement important pour les conteneurs **rootless**.

Conceptuellement :

``` text
Container UID 0
       │
       ▼
Host UID 100000
```

Ainsi :

> **root dans le conteneur n'est pas nécessairement root sur l'hôte.**

Le mapping peut être observé avec :

``` bash
cat /proc/$$/uid_map
cat /proc/$$/gid_map
```

Cette technique permet de réduire les privilèges réels du processus sur
l'hôte.

------------------------------------------------------------------------

# 19. Namespaces : isolation de la visibilité

Une manière simple de retenir le rôle des namespaces est de poser la
question :

> **What can the process see?**

Exemples :

``` text
PID namespace
→ Quels processus puis-je voir ?

NET namespace
→ Quelles interfaces et routes réseau puis-je voir ?

MNT namespace
→ Quels mounts puis-je voir ?

UTS namespace
→ Quel hostname vois-je ?

USER namespace
→ Quelle identité UID/GID ai-je ?
```

Les namespaces sont donc principalement associés à **l'isolation de la
visibilité et de l'environnement**.

------------------------------------------------------------------------

# 20. Les Linux cgroups

Les namespaces ne suffisent pas.

Un processus isolé pourrait toujours consommer énormément de CPU ou de
mémoire.

C'est là qu'interviennent les **control groups (cgroups)**.

Les cgroups permettent de contrôler et comptabiliser l'utilisation des
ressources par des groupes de processus.

Ils peuvent notamment être utilisés pour contrôler :

-   CPU ;
-   mémoire ;
-   nombre de processus ;
-   I/O ;
-   autres ressources exposées par les contrôleurs disponibles.

## Exemple avec Docker

``` bash
docker run \
  --memory=512m \
  --cpus=1 \
  nginx
```

Conceptuellement :

``` text
                 Container
                     │
             ┌───────┼───────┐
             ▼       ▼       ▼
            CPU    Memory    PIDs
          1 CPU    512 MB    limit
```

Le runtime configure alors les mécanismes nécessaires pour appliquer ces
contraintes.

------------------------------------------------------------------------

# 21. Namespaces vs cgroups

C'est une distinction fondamentale.

  Mécanisme    Question principale
  ------------ ----------------------------------------------
  Namespaces   **Que peut voir le processus ?**
  cgroups      **Combien de ressources peut-il utiliser ?**

À retenir :

``` text
Namespaces → Isolation
cgroups    → Resource control
```

Un conteneur moderne combine généralement les deux.

``` text
Container
   │
   ├── namespaces
   │      └── isolation
   │
   └── cgroups
          └── resource control
```

------------------------------------------------------------------------

# 22. `unshare`, `clone()` et `setns()`

## `unshare`

`unshare` permet à un processus de se séparer de certains namespaces.

Exemple :

``` bash
unshare --pid --fork --mount-proc bash
```

Le processus lancé possède alors un environnement PID isolé.

Pour tester plusieurs namespaces :

``` bash
unshare --pid --fork --mount-proc \
        --mount \
        --uts \
        --net \
        bash
```

Puis :

``` bash
ps aux
hostname
ip addr
mount
```

> Les options exactes disponibles peuvent dépendre de la version de
> `util-linux` et du système.

## `clone()`

`clone()` est un appel système Linux permettant de créer un processus
avec un contrôle plus fin sur les ressources et namespaces partagés ou
isolés.

Conceptuellement :

``` text
clone()
  │
  ├── PID namespace
  ├── NET namespace
  ├── MNT namespace
  ├── UTS namespace
  ├── IPC namespace
  └── USER namespace
```

C'est une primitive particulièrement importante pour comprendre comment
un runtime peut créer l'environnement d'un conteneur.

## `setns()`

`setns()` permet à un processus d'entrer dans un namespace existant.

Conceptuellement :

``` text
Process A
   │
   └── Namespace X

Process B
   │
   │ setns()
   ▼
Namespace X
```

Ces trois primitives peuvent être résumées ainsi :

  Primitive     Rôle
  ------------- ---------------------------------------------------
  `clone()`     Créer un processus avec des namespaces configurés
  `unshare()`   Créer / détacher le processus de namespaces
  `setns()`     Entrer dans un namespace existant

------------------------------------------------------------------------

# 23. Construire un mini-conteneur sans Docker

L'objectif du lab est de reproduire manuellement une partie du travail
réalisé par un runtime de conteneurs.

Le workflow conceptuel est :

``` text
Linux process
      │
      ▼
Create rootfs
      │
      ▼
Mount filesystem
      │
      ▼
Create namespaces
      │
      ▼
Configure cgroups
      │
      ▼
Start isolated process
      │
      ▼
Mini-container
```

## 23.1 Préparer l'environnement

Les manipulations de namespaces, mounts et cgroups nécessitent des
privilèges adaptés.

Sur un système de laboratoire Red Hat :

``` bash
cat /etc/redhat-release
uname -r
```

Vérifier les commandes :

``` bash
which unshare
which mount
which chroot
which findmnt
```

------------------------------------------------------------------------

## 23.2 Créer un rootfs minimal

Créer l'arborescence :

``` bash
mkdir -p ~/container-lab/rootfs
```

Une approche pédagogique consiste à construire un rootfs contenant au
minimum un shell et ses dépendances.

Sur un environnement de laboratoire, vous pouvez utiliser une
image/rootfs préparé à cet effet plutôt que copier arbitrairement les
fichiers de l'hôte.

Vérifier :

``` bash
ls -la ~/container-lab/rootfs
```

Structure cible :

``` text
rootfs/
├── bin/
├── etc/
├── lib/
├── lib64/
├── proc/
├── sys/
├── dev/
├── tmp/
├── usr/
└── var/
```

------------------------------------------------------------------------

## 23.3 Tester le rootfs avec `chroot`

Une fois le rootfs correctement préparé :

``` bash
chroot ~/container-lab/rootfs /bin/bash
```

Puis :

``` bash
pwd
ls /
```

Vous devez voir le rootfs comme racine.

### Sortir

``` bash
exit
```

### Limite de cette étape

À ce stade, vous n'avez pas encore un conteneur moderne.

Vous avez principalement modifié la vue du filesystem.

Il manque notamment :

``` text
PID namespace
NET namespace
MNT namespace
UTS namespace
USER namespace
cgroups
```

------------------------------------------------------------------------

## 23.4 Créer un environnement isolé avec `unshare`

Un exemple pédagogique :

``` bash
unshare --pid --fork --mount-proc \
        --mount \
        --uts \
        --net \
        bash
```

Vérifier le PID :

``` bash
echo $$
```

Puis :

``` bash
ps aux
```

Vous devez observer une vue des processus différente de celle de l'hôte.

Tester le hostname :

``` bash
hostname
```

Vous pouvez ensuite modifier le hostname dans ce namespace :

``` bash
hostname mini-container
```

Puis :

``` bash
hostname
```

Le hostname du namespace est indépendant de celui de l'hôte.

------------------------------------------------------------------------

## 23.5 Observer les namespaces

Depuis l'environnement :

``` bash
ls -l /proc/$$/ns/
```

Depuis un autre terminal, sur l'hôte :

``` bash
ls -l /proc/1/ns/
```

Comparer par exemple :

``` bash
readlink /proc/1/ns/pid
readlink /proc/$$/ns/pid
```

Pour le réseau :

``` bash
readlink /proc/1/ns/net
readlink /proc/$$/ns/net
```

Des valeurs différentes indiquent des namespaces différents.

------------------------------------------------------------------------

## 23.6 Comprendre le rôle de `/proc`

Lorsque vous utilisez un PID namespace, `/proc` doit être correctement
monté pour que les outils comme `ps` présentent la vue correspondant au
namespace.

Dans un environnement de test approprié :

``` bash
mount -t proc proc /proc
```

ou utilisez directement :

``` bash
unshare --pid --fork --mount-proc bash
```

qui facilite cette configuration.

------------------------------------------------------------------------

## 23.7 Limiter les ressources avec les cgroups

Le principe est de placer le processus dans un cgroup puis de définir
des limites.

Selon la version de Red Hat et la configuration du système, vous pouvez
rencontrer **cgroup v1 ou cgroup v2**.

Vérifier :

``` bash
stat -fc %T /sys/fs/cgroup
```

et :

``` bash
mount | grep cgroup
```

Sur un système cgroup v2, vous pouvez inspecter :

``` bash
ls /sys/fs/cgroup
```

La syntaxe et les fichiers disponibles doivent être vérifiés sur le
système de laboratoire avant d'appliquer les commandes.

### Exemple conceptuel

``` text
container cgroup
│
├── CPU limit
├── Memory limit
├── PID limit
└── I/O control
```

L'objectif pédagogique est de comprendre que le runtime associe le
processus du conteneur à un groupe auquel le noyau applique des
contraintes.

------------------------------------------------------------------------

# 24. Observer et vérifier le conteneur

Un mini-conteneur doit être observé depuis plusieurs angles.

## Processus

``` bash
ps aux
pstree
```

## Namespaces

``` bash
ls -l /proc/$$/ns/
```

## Mounts

``` bash
findmnt
cat /proc/self/mountinfo
```

## Réseau

``` bash
ip addr
ip route
```

## Hostname

``` bash
hostname
```

## Identité

``` bash
id
cat /proc/$$/uid_map
cat /proc/$$/gid_map
```

## Cgroups

``` bash
cat /proc/$$/cgroup
```

Selon la configuration cgroup v2 :

``` bash
find /sys/fs/cgroup -maxdepth 2 -type f | head
```

------------------------------------------------------------------------

# 25. Relier le mini-conteneur à `runc`, `containerd` et Docker

Maintenant que nous avons construit manuellement une partie de
l'environnement, il devient possible de comprendre pourquoi les runtimes
existent.

## 25.1 Le problème

Faire manuellement :

``` text
rootfs
mounts
namespaces
cgroups
process
network
security
...
```

pour chaque conteneur serait complexe et difficile à industrialiser.

Il faut donc standardiser et automatiser ce processus.

------------------------------------------------------------------------

## 25.2 OCI

L'**Open Container Initiative (OCI)** définit notamment des standards
pour :

-   le format des images ;
-   l'exécution des conteneurs.

Le Runtime Specification décrit notamment une configuration telle que :

``` text
config.json
rootfs
process
namespaces
mounts
resources
```

Conceptuellement :

``` text
config.json
     │
     ▼
   OCI Runtime
     │
     ├── namespaces
     ├── cgroups
     ├── mounts
     ├── rootfs
     └── process
           │
           ▼
      Linux Kernel
```

------------------------------------------------------------------------

## 25.3 `runc`

`runc` est un runtime OCI.

Son rôle est de prendre la configuration nécessaire à l'exécution du
conteneur et de mettre en place l'environnement demandé.

Conceptuellement :

``` text
OCI configuration
       │
       ▼
      runc
       │
       ├── namespaces
       ├── cgroups
       ├── mounts
       ├── rootfs
       └── process
             │
             ▼
        Linux Kernel
```

Notre mini-conteneur manuel permet donc de comprendre **ce que runc
automatise**.

------------------------------------------------------------------------

## 25.4 `containerd`

`containerd` se situe à une couche supérieure au runtime OCI.

Il prend notamment en charge des responsabilités liées à :

``` text
Image management
     │
     ├── pull
     ├── content store
     ├── unpack
     └── snapshots

Container lifecycle
     │
     ▼
OCI runtime
     │
     ▼
runc / crun
```

Par exemple :

``` bash
ctr images pull docker.io/library/alpine:latest
```

`containerd` gère l'image et son stockage avant de demander à un runtime
OCI d'exécuter le conteneur.

------------------------------------------------------------------------

## 25.5 Docker

La chaîne simplifiée peut être représentée ainsi :

``` text
                     docker run
                         │
                         ▼
                   Docker Engine
                         │
                         ▼
                      containerd
                         │
                         ▼
                      runc / crun
                         │
                         ▼
                    Linux Kernel
```

Lorsque vous exécutez :

``` bash
docker run -d --name web -p 8080:80 nginx
```

Docker orchestre de nombreuses opérations :

``` text
Docker
 │
 ├── image
 │    ├── layers
 │    └── rootfs
 │
 ├── container
 │
 ├── namespaces
 │    ├── PID
 │    ├── NET
 │    ├── MNT
 │    ├── UTS
 │    ├── IPC
 │    └── USER
 │
 ├── cgroups
 │
 ├── networking
 │
 └── volumes
```

------------------------------------------------------------------------

# 26. Résumé

La conteneurisation moderne repose sur plusieurs primitives Linux
complémentaires.

## Processus

``` text
fork()
exec()
/proc
```

Ils permettent de comprendre le modèle de processus Linux.

## Filesystem

``` text
rootfs
mount
bind mount
chroot
pivot_root
```

Ils permettent de construire la vue filesystem du processus.

## Namespaces

``` text
PID
NET
MNT
UTS
IPC
USER
```

Ils permettent principalement d'isoler la **vue du système**.

## cgroups

``` text
CPU
Memory
PIDs
I/O
```

Ils permettent principalement de contrôler les **ressources**.

## Primitives de namespaces

``` text
clone()
unshare()
setns()
```

Elles permettent de créer, quitter ou rejoindre des environnements de
namespaces.

## Runtime

``` text
OCI
  │
  ▼
runc / crun
  │
  ▼
Linux Kernel
```

## Container manager

``` text
containerd
    │
    ▼
OCI Runtime
```

## Platform / user experience

``` text
Docker
  │
  ▼
containerd
  │
  ▼
runc
  │
  ▼
Linux Kernel
```

### La phrase à retenir

> **Docker does not create a new operating system for each container. It
> asks Linux to create isolated processes using kernel primitives such
> as namespaces, cgroups, mounts, and filesystem isolation.**

------------------------------------------------------------------------

# 27. Travaux pratiques

## Lab --- Construction d'un mini-conteneur Linux

### Objectif

Construire un environnement ressemblant à un conteneur **sans utiliser
Docker**, puis observer les mécanismes Linux utilisés.

### Partie 1 --- Processus

1.  Afficher les processus de l'hôte :

``` bash
ps aux
```

2.  Afficher votre PID :

``` bash
echo $$
```

3.  Observer `/proc` :

``` bash
ls /proc/$$
```

------------------------------------------------------------------------

### Partie 2 --- Rootfs

Créer :

``` bash
mkdir -p ~/container-lab/rootfs
```

Préparer un rootfs minimal.

Tester :

``` bash
chroot ~/container-lab/rootfs /bin/bash
```

Questions :

-   Quelle est la nouvelle racine ?
-   Pourquoi `chroot` seul ne constitue-t-il pas un conteneur complet ?
-   Quels éléments sont encore partagés avec l'hôte ?

------------------------------------------------------------------------

### Partie 3 --- PID namespace

Lancer :

``` bash
unshare --pid --fork --mount-proc bash
```

Puis :

``` bash
ps aux
```

Comparer avec :

``` bash
ps aux
```

sur l'hôte.

Questions :

-   Quel processus possède le PID `1` dans le namespace ?
-   Pourquoi la liste des processus est-elle différente ?

------------------------------------------------------------------------

### Partie 4 --- UTS namespace

Créer le namespace :

``` bash
unshare --uts --fork bash
```

Puis :

``` bash
hostname
```

Modifier le hostname :

``` bash
hostname mini-container
```

Vérifier sur l'hôte que le hostname n'a pas changé.

------------------------------------------------------------------------

### Partie 5 --- Network namespace

Créer :

``` bash
unshare --net --fork bash
```

Puis :

``` bash
ip addr
ip route
```

Questions :

-   Quelles interfaces sont visibles ?
-   Pourquoi le réseau est-il différent de celui de l'hôte ?

------------------------------------------------------------------------

### Partie 6 --- Inspection des namespaces

Comparer :

``` bash
readlink /proc/1/ns/pid
readlink /proc/$$/ns/pid
```

Puis :

``` bash
readlink /proc/1/ns/net
readlink /proc/$$/ns/net
```

Répéter pour :

``` text
mnt
uts
ipc
user
```

------------------------------------------------------------------------

### Partie 7 --- Cgroups

Identifier la version :

``` bash
stat -fc %T /sys/fs/cgroup
```

Inspecter :

``` bash
cat /proc/$$/cgroup
```

Identifier les contrôleurs disponibles et expliquer comment un runtime
pourrait imposer :

``` text
CPU
Memory
PIDs
I/O
```

------------------------------------------------------------------------

### Partie 8 --- Synthèse

Compléter le schéma :

``` text
                    Mini-container
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
     Filesystem        Isolation        Resources
          │                │                │
          ▼                ▼                ▼
      rootfs          namespaces        cgroups
          │                │
          │        ┌───────┼────────┐
          │        ▼       ▼        ▼
          │       PID     NET      MNT
          │
          └──────────────┬──────────────┐
                         ▼              ▼
                       process       Linux Kernel
```

------------------------------------------------------------------------

# 28. Questions de compréhension

### Q1. Un conteneur possède-t-il son propre kernel ?

**Réponse :** non. Les conteneurs partagent le noyau Linux de l'hôte.

### Q2. Quel est le rôle principal des namespaces ?

Ils fournissent une vue isolée de différentes ressources du système.

### Q3. Quel est le rôle principal des cgroups ?

Contrôler et comptabiliser les ressources consommées par les groupes de
processus.

### Q4. Quelle est la différence fondamentale ?

``` text
Namespaces → What can I see?
cgroups    → How much can I use?
```

### Q5. `chroot` suffit-il à créer un conteneur moderne ?

Non. `chroot` agit principalement sur la racine filesystem visible par
le processus. Un conteneur moderne combine plusieurs mécanismes.

### Q6. Pourquoi `root` dans un conteneur peut-il ne pas être root sur l'hôte ?

Grâce notamment aux user namespaces et aux mappings UID/GID.

### Q7. Quel est le rôle de `runc` ?

`runc` est un runtime OCI chargé d'exécuter un conteneur conformément à
une configuration OCI.

### Q8. Quel est le rôle de `containerd` ?

Il fournit notamment des fonctions de gestion du cycle de vie des
conteneurs et des images et s'appuie sur un runtime OCI pour
l'exécution.

### Q9. Pourquoi construire un conteneur sans Docker ?

Pour comprendre les mécanismes que Docker et les autres outils
abstraient.

------------------------------------------------------------------------

## À retenir avant le chapitre suivant

Le cheminement que nous venons de suivre est :

``` text
Linux Process
     │
     ├── fork / exec
     │
     ▼
Filesystem
     │
     ├── rootfs
     ├── mount
     ├── chroot
     └── pivot_root
     │
     ▼
Namespaces
     │
     ├── PID
     ├── NET
     ├── MNT
     ├── UTS
     ├── IPC
     └── USER
     │
     ▼
cgroups
     │
     ▼
Mini-container
     │
     ▼
        OCI
         │
         ▼
      runc / crun
         │
         ▼
      containerd
         │
         ▼
       Docker
```

Le chapitre suivant partira de cette base pour expliquer **comment ces
mécanismes sont standardisés par OCI et industrialisés par les runtimes
modernes comme `runc` et `containerd`**.
