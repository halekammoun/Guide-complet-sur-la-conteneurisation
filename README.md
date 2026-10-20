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
- [Fondations Linux et Isolation](01-linux-foundations.md) `inclu dans l'examen`
- [Construire un conteneur manuellement](TPs/TP-01.md)
- [Standards OCI, Runtime moderne et exécution avec containerd](02-Container-runtime-et-OCI.md) `inclu dans l'examen`  
  [Gérer les conteneurs avec Containerd](TPs/TP-02.md) `inclu dans l'examen`
- [Gérer les conteneurs avec Podman Cours](03-podman.md), [Guide nginx proxy](guide_nginx.md) et [TP](TPs/TP-03.md) `inclu dans l'examen`
- [Gérer les conteneurs avec Docker](04-docker.md) et [Test](https://github.com/halekammoun/Test-Docker/) `inclu dans l'examen`
- [Réseau des conteneurs et CNI](empty)
- [Registry et Sécurité des conteneurs](empty) 