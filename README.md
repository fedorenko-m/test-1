# Hello Nginx — Docker + CI/CD

A static "Hello, World!" page served by Nginx in Docker. Every push to `main` builds the image, pushes it to Docker Hub and deploys it to a test server.

## Structure

```
app/index.html               the web page
nginx/default.conf           Nginx config: site, /healthz, JSON access log, stub_status for metrics
Dockerfile                   non-root Nginx image with a health check
scripts/deploy.sh            build, push and deploy (with health check and rollback)
deploy/docker-compose.yml    what runs on the server: app + metrics exporter + Prometheus
deploy/prometheus.yml        Prometheus config
.github/workflows/ci-cd.yml  GitHub Actions pipeline
terraform/                   example infrastructure (AWS EC2 with Docker)
```

## How it works

1. **Dockerfile** — based on `nginx-unprivileged`, so Nginx does not run as root. It listens on port `8080`. Docker checks `/healthz` every 10 seconds.
2. **scripts/deploy.sh** — one script for local use and for CI:
   - `build` — builds the image with two tags: the commit hash and `latest`;
   - `push` — pushes both tags to the registry;
   - `deploy` — copies `deploy/` to the server over SSH, starts the new image with Docker Compose and checks `/healthz`. If the check fails, it starts the previous version again;
   - `all` — all three steps.
3. **GitHub Actions** — on every push to `main`:
   - `lint` — checks the Dockerfile (hadolint) and the script (shellcheck);
   - `build` — builds the image, starts it and checks the page (smoke test), then pushes it;
   - `deploy` — runs `scripts/deploy.sh deploy` and checks the public URL. Only one deploy runs at a time.

   Pull requests only run `lint` and `build` without pushing or deploying.

## Run locally

You only need Docker.

```bash
docker build -t hello-nginx .
docker run --rm -p 8080:8080 hello-nginx
```

Open http://localhost:8080.

## Set up the test server

Any Linux server with Docker and SSH access works. `terraform/` contains an example for AWS:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # put your public SSH key here
terraform init
terraform apply
```

It creates an EC2 instance, opens ports 80 and 22, installs Docker and creates the user `deploy`. The output `public_ip` is the server address.

For your own server, do the same by hand: install Docker, create a user `deploy` in the `docker` group and add the public SSH key to it.

## Set up CI/CD (GitHub)

In **Settings → Secrets and variables → Actions** add:

| Name | Type | Value |
|---|---|---|
| `IMAGE` | variable | image name, e.g. `myuser/hello-nginx` |
| `DOCKERHUB_USERNAME` | secret | Docker Hub user |
| `DOCKERHUB_TOKEN` | secret | Docker Hub access token |
| `DEPLOY_HOST` | secret | server IP or domain |
| `DEPLOY_USER` | secret | SSH user on the server (`deploy`) |
| `DEPLOY_SSH_KEY` | secret | private SSH key of that user |

Also create the environment `test` (**Settings → Environments**). After that every push to `main` deploys the site to `http://<DEPLOY_HOST>/hello`.

## Deploy by hand

```bash
docker login
IMAGE=myuser/hello-nginx DEPLOY_HOST=1.2.3.4 scripts/deploy.sh all
```

## Monitoring and logs

- **Metrics** — `nginx-prometheus-exporter` reads Nginx `stub_status` and Prometheus collects it. Prometheus is open only on the server itself:
  ```bash
  ssh -L 9090:127.0.0.1:9090 deploy@<DEPLOY_HOST>
  ```
  Then open http://localhost:9090.
- **Logs** — Nginx writes the access log in JSON to stdout. Docker keeps up to 3 files of 10 MB per container:
  ```bash
  ssh deploy@<DEPLOY_HOST> "cd /opt/hello-nginx && docker compose logs -f app"
  ```

## Notes

- Kubernetes is not used on purpose: one container on one server is enough here.
- Terraform is a working example, but it was not applied, because there is no cloud account for this task.
