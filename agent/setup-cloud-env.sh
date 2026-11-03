#!/usr/bin/env bash
# Script d'installation de l'environnement cloud des agents Écluse.
#
# À coller dans le champ « Setup script » de l'environnement cloud utilisé
# par les tâches planifiées. Il reproduit l'outillage de la CI
# (.github/workflows/ci.yml) : Dart stable et Melos. Python est déjà
# présent sur les VM cloud.
#
# Réseau : n'utilise que storage.googleapis.com et pub.dev, deux domaines
# de la liste « Trusted » par défaut des environnements cloud. Le dépôt APT
# de Google n'est pas utilisé car sa clé de signature est servie par un
# domaine absent de cette liste.
#
# Le résultat est mis en cache par l'environnement : ce script ne tourne
# pas à chaque exécution. Les VM cloud exécutent ce script en root.

set -euo pipefail

DART_ROOT=/opt/dart-sdk
DART_ZIP_URL="https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip"

# --- Dart SDK --------------------------------------------------------------
if [ ! -x "$DART_ROOT/bin/dart" ]; then
  command -v unzip >/dev/null 2>&1 || { apt-get update -y && apt-get install -y unzip; }
  tmp="$(mktemp -d)"
  curl -fsSL "$DART_ZIP_URL" -o "$tmp/dartsdk.zip"
  unzip -q "$tmp/dartsdk.zip" -d /opt
  rm -rf "$tmp"
fi
export PATH="$PATH:$DART_ROOT/bin:$HOME/.pub-cache/bin"
dart --version

# --- Melos -----------------------------------------------------------------
dart pub global activate melos
melos --version

# --- PATH persistant pour les sessions -------------------------------------
PROFILE_LINE="export PATH=\"\$PATH:$DART_ROOT/bin:\$HOME/.pub-cache/bin\""
grep -qxF "$PROFILE_LINE" "$HOME/.bashrc" 2>/dev/null \
  || echo "$PROFILE_LINE" >> "$HOME/.bashrc"

# Les dépendances Python du benchmark (bench/requirements.txt) et
# `melos bootstrap` sont installées par l'agent dans la session, depuis la
# racine du dépôt : voir la section « Commandes » de CLAUDE.md.

echo "Outillage Écluse prêt."
