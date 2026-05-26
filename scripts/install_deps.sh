#!/usr/bin/env bash
set -Eeuo pipefail

sudo apt update
sudo apt install -y \
  build-essential \
  make \
  gcc \
  python3 \
  ffmpeg \
  stress-ng \
  glmark2

cat <<'MSG'
Dependências instaladas.
Observação: dependendo da imagem do Raspberry Pi OS, o executável de GPU pode aparecer como glmark2, glmark2-es2-drm ou glmark2-es2-wayland.
MSG
