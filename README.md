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

# 📖 Table of Contents
- [Séance 1 - Introduction au conteneurisation et Construire un conteneur manuellement](00-linux-foundations.md)
- [Séance 2 - OCI, containerd et runc](01-oci-containerd-runc.md)
- [LAB d'évaluation 01](TP-01.md)
- [Séance 3 - Container Networking et CNI](02-container-networking-cni.md)
- [Séance 4 - Private Registry et Container Security](03-registry-and-security.md)
- [LAB d'évaluation 02](TP-02.md)
- [Séance 5 - Docker et Podman](04-docker-and-podman.md)
- [Séance 6 - Docker Compose et orchestration locale](05-docker-compose.md)
- [LAB d'évaluation 03](TP-03.md)
