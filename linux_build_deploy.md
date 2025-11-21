• Linux x64 Build

- Install Node 22+, Yarn 4 (corepack enable && corepack prepare yarn@stable --activate), and Rust 1.87 as described in
  BUILD_GUIDE_CN.md:112-175.
- From repo root, install dependencies and build only the pieces needed for a Linux web deployment (no desktop/mobile client build):
  - Backend native binding and reader:
    yarn install
    yarn affine @affine/server-native build
    yarn affine @affine/reader build
    (You do not need to run yarn affine @affine/native build, nor any @affine/electron / @affine/android / @affine/ios scripts on a
    Linux server.)
  - Web frontends (browser bundles served by the backend container):
    yarn affine @affine/web build
    yarn affine @affine/admin build
    yarn affine @affine/mobile build
    These commands only produce static assets under packages/frontend/apps/{web,admin,mobile}/dist and do not build any desktop or
    native mobile apps.
  - Backend server bundle:
    yarn workspace @affine/server build
    This generates packages/backend/server/dist/main.js, which Dockerfile.backend.custom uses as the server entry point.
- Build the self-hosted backend image that bakes in the server bundle and web assets:
  docker build -f Dockerfile.backend.custom -t localhost/affine-backend:custom .
  compose-app.yml is already wired to use this tag (image: localhost/affine-backend:custom), so no extra image configuration is
  required unless you explicitly want to switch to the official ghcr.io/toeverything/affine images.

Prepare Split Deployment

- All compose files and env templates live in .docker/selfhost-split (README.md there has a diagram and ops tips).
- Copy the env templates to working files and edit secrets/hosts:
  cp .docker/selfhost-split/.env.middleware .docker/selfhost-split/.env.middleware.local and cp .docker/selfhost-
  split/.env.app .docker/selfhost-split/.env.app.local.
  Update DB/Redis passwords and data paths in .env.middleware.local (.docker/selfhost-split/.env.middleware:1-32), and set DB_HOST,
  REDIS_SERVER_HOST, mail/search hosts, etc., in .env.app.local (.docker/selfhost-split/.env.app:1-52).

Deploy Middleware Stack

1. cd .docker/selfhost-split
2. Launch PostgreSQL/Redis/Mailpit/Manticore with your env file:
   docker compose -f compose-middleware.yml --env-file .env.middleware.local up -d (compose-middleware.yml:1-78).
3. Verify health: docker compose -f compose-middleware.yml ps and docker compose -f compose-middleware.yml logs -f postgres (adjust
   service name as needed).
4. If middleware sits on a separate host, lock down ports 5432/6379/9308/1025 to only allow the app server’s IP.

Deploy Application Stack

1. Still under .docker/selfhost-split, ensure .env.app.local points to the middleware host. By default compose-app.yml:7-74 uses
   image: localhost/affine-backend:custom, so as long as you have built that image in the previous step you do not need to change
   anything. If you prefer to use the official image, edit image: to ghcr.io/toeverything/affine:stable/beta/canary instead.
2. Start the migration job + main server:
   docker compose -f compose-app.yml --env-file .env.app.local up -d.
   affine_migration runs once (compose-app.yml:9-31) and affine starts afterward (compose-app.yml:33-80).
3. Check status/logs:
   docker compose -f compose-app.yml ps
   docker compose -f compose-app.yml logs -f affine.
4. Confirm the app is reachable: curl http://<app-host>:3010/api/healthz. Set up an external reverse proxy (Nginx/Caddy) if you need
   HTTPS or load balancing.

Ongoing Ops

- Middleware data lives under .docker/selfhost-split/data/\*; back it up regularly.
- To update versions, either rebuild the localhost/affine-backend:custom image (rerun the build + docker build steps above) and then
  run docker compose … up -d --force-recreate for the app stack, or switch compose-app.yml to a tagged upstream
  ghcr.io/toeverything/affine:<version> image and use docker compose … pull + docker compose … up -d.
- Use docker compose … down -v on each stack to tear everything down safely when needed.

That flow gives you a clean Linux x64 build plus the requested split deployment where middleware and application lifecycles stay
independent.
