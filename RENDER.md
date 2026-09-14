# Demo gratuita en Render con nuestro proxy

Se utilizan las tres imágenes publicadas por nuestro pipeline y un Key Value
compatible con Redis. Crear todos los servicios en el mismo workspace y región.

```text
Navegador -> proxy (nuestra imagen) -> frontend (nuestra imagen)
                                  -> API (nuestra imagen) -> Key Value
```

Los tres contenedores son **Web Services / Existing Image / Free**. Los servicios
Free no reciben conexiones por red privada; el proxy usa los dominios públicos
HTTPS de frontend y API. Redis se conecta por la red privada desde la API.
En la demo hay una instancia de cada servicio. Compose conserva sus tres
frontends, tres APIs y Redis con volumen.

## 1. Key Value

- New > Key Value, plan Free, misma región que la API.
- Maxmemory Policy: `noeviction` para no descartar tareas al llenarse.
- Copiar el host y puerto de Connect > Internal. Mantener acceso externo bloqueado.
- El cliente actual usa la conexión interna sin autenticación; no acepta
  `REDIS_URL`, contraseña ni TLS de Redis mediante variables.
- Free no tiene persistencia: al reiniciarse Key Value se pierden los datos.

## 2. API

- Imagen: `docker.io/joabresper/tp1-devops-api:latest`.
- Docker Command: vacío (usar el de la imagen).
- Variables: `NODE_ENV=production`, `PORT=10000`, `REDIS_HOST=<host interno>`,
  `REDIS_PORT=6379` (usar el puerto real mostrado por Render).
- Health Check Path: `/api/health`.
- Desplegar y comprobar `https://<dominio-api>/api/health`.

## 3. Frontend

- Imagen: `docker.io/joabresper/tp1-devops-app-web:latest`.
- Variable: `PORT=80`, correspondiente al puerto de Nginx en esta imagen.
- Docker Command: **vacío**. Quitar cualquier comando anterior que agregara
  el proxy dentro del frontend. No necesita `API_HOST`.
- Health Check Path: `/`.
- Desplegar y copiar el dominio público. La aplicación completa se abre por el
  proxy; abrir el frontend directamente muestra la UI pero sus `/api/` fallan.

## 4. Nuestro proxy

Primero deben publicarse los cambios de esta rama: commit/PR a main, pipeline
aprobado y nueva imagen de proxy disponible en Docker Hub. El pipeline existente
ya construye `proxy/Dockerfile`; no necesita cambios para incluir la plantilla.

- Imagen: `docker.io/joabresper/tp1-devops-proxy:latest`.
- Docker Command: **vacío** (se usa el entrypoint oficial de Nginx).
- Health Check Path: `/health`.
- Variables:

| Variable | Valor |
| --- | --- |
| `PORT` | `10000` |
| `API_HOST` | Dominio público de la API, sin `https://`, puerto ni rutas |
| `FRONTEND_HOST` | Dominio público del frontend, sin `https://`, puerto ni rutas |
| `NGINX_ENVSUBST_TEMPLATE_DIR` | `/opt/render-templates` |
| `NGINX_ENVSUBST_OUTPUT_DIR` | `/etc/nginx` |

El entrypoint de Nginx sustituye estas variables en
`proxy/render/nginx.conf.template` al arrancar. Se verifica el certificado TLS
de los destinos y se envían Host y SNI correspondientes a cada dominio.
Las rutas y cuerpos de las peticiones se conservan: `/api/tareas` va a la API,
las demás rutas al frontend. No se habilitan reintentos de POST ya enviados.

Abrir **la URL pública del proxy** y probar crear, editar y eliminar una tarea.
`/health` comprueba solo el proxy; `/api/health` comprueba API y Redis.

Los servicios Free se suspenden tras 15 minutos sin tráfico. Abrir primero
frontend y `/api/health` antes de la demo para despertarlos. El proxy permite
90 segundos de espera, pero Render puede responder con su pantalla de arranque;
si ocurre, esperar y recargar. No es una configuración para producción.

## Actualizar y probar

Cuando el CI publique una imagen nueva, en el servicio correspondiente usar
Manual Deploy > Deploy latest reference. Render no despliega automáticamente
porque cambió `latest`.

Con Docker y una terminal `sh` (por ejemplo Git Bash), desde la raíz:

```sh
sh proxy/test.sh
```

Esta prueba construye la imagen, valida la configuración de Compose y comprueba
el arranque y health del modo Render, sin tocar los contenedores ni los datos
de la aplicación. No reemplaza la prueba final contra los servicios de Render.

Referencias: [imágenes existentes](https://render.com/docs/deploying-an-image),
[límites Free](https://render.com/docs/free),
[Key Value](https://render.com/docs/key-value).
