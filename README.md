#  Guide complet sur la conteneurisation

Bienvenue dans ce guide complet consacré à la **conteneurisation moderne**.

Ce repository propose une approche progressive et pratique de la conteneurisation, depuis les mécanismes fondamentaux du noyau Linux jusqu'à l'utilisation de Docker, Podman et Docker Compose.

L'objectif est de comprendre non seulement **comment utiliser les conteneurs**, mais surtout **comment ils fonctionnent sous le capot**.

---

## 🎯 Objectifs

À la fin de ce guide, vous serez capable de :

- Comprendre les mécanismes fondamentaux de la conteneurisation sous Linux
- Comprendre les processus, namespaces et cgroups
- Construire un conteneur manuellement sans Docker
- Comprendre les standards OCI
- Comprendre le rôle de `runc`, `crun` et `containerd`
- Exécuter des conteneurs avec `containerd`
- Comprendre le réseau des conteneurs
- Configurer un réseau Linux avec bridge et veth
- Comprendre le fonctionnement de CNI
- Déployer un Registry privé
- Configurer l'authentification et TLS
- Comprendre les mécanismes de sécurité des conteneurs
- Utiliser les capabilities, seccomp, SELinux et le mode rootless
- Utiliser Docker
- Utiliser Podman en mode rootless (Préaparation Certification rhcsc: RedHat Certified Specialist in containers)
- Déployer des applications multi-conteneurs avec Docker Compose

---

## 📚 Prérequis

Ce guide suppose des connaissances de base en :

- Linux / Red Hat Enterprise Linux
- Administration système
- Réseaux informatiques
- Virtualisation

---

# 📖 Sommaire
- [Chapitre 00 - Introduction au conteneurisation & Construire un conteneur manuellement](00-linux-foundations.md)
- [Chapitre 01 - OCI & runtimes](01-Container-runtime-et-OCI.md)
- [Chapitre 02 - Réseaux des conteneurs & CNI](02-container-networking-cni.md)
- [Chapitre 03 - Docker](04-docker-and-podman.md)
- [Chapitre 04 - Podman](05-docker-compose.md)
- [Chapitre 05 - Sécurisation des conteneurs & Registre privé](03-registry-and-security.md)
