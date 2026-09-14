#!/bin/sh
set -eu
# Git Bash debe pasar las rutas Linux a Docker sin convertirlas a rutas Windows.
export MSYS_NO_PATHCONV=1

cd "$(dirname "$0")/.."
docker build -t tp1-proxy-check:local proxy

# Compose sigue arrancando con sus nombres internos y sin variables de Render.
docker run --rm --add-host api:127.0.0.1 --add-host app-web:127.0.0.1 \
    tp1-proxy-check:local nginx -t

# Render debe arrancar sin DNS de Compose, generar la plantilla y servir health.
docker run --rm \
    --add-host api.render.test:127.0.0.1 \
    --add-host web.render.test:127.0.0.1 \
    -e PORT=10000 \
    -e API_HOST=api.render.test \
    -e FRONTEND_HOST=web.render.test \
    -e NGINX_ENVSUBST_TEMPLATE_DIR=/opt/render-templates \
    -e NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx \
    tp1-proxy-check:local sh -ec '
        /docker-entrypoint.sh nginx -t
        nginx
        wget -qO- http://127.0.0.1:10000/health | grep -F "\"service\":\"proxy\""
    '
