#!/usr/bin/env bash
#
# Build, push and deploy the Docker image.
#
# Usage: scripts/deploy.sh [build|push|deploy|all]
#
# Environment:
#   IMAGE        image name in the registry, e.g. myuser/hello-nginx   (required)
#   TAG          image tag; defaults to the short git commit hash
#   DEPLOY_HOST  test server address                                    (required for deploy)
#   DEPLOY_USER  SSH user on the server                                 (default: deploy)
#   DEPLOY_PATH  directory on the server for the compose files          (default: /opt/hello-nginx)
#   SSH_PORT     SSH port                                               (default: 22)

set -euo pipefail

: "${IMAGE:?IMAGE is required, e.g. IMAGE=myuser/hello-nginx}"
TAG="${TAG:-$(git rev-parse --short HEAD)}"
DEPLOY_USER="${DEPLOY_USER:-deploy}"
DEPLOY_PATH="${DEPLOY_PATH:-/opt/hello-nginx}"
SSH_PORT="${SSH_PORT:-22}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

log() {
    printf '\n==> %s\n' "$*"
}

build() {
    log "Building ${IMAGE}:${TAG}"
    docker build --pull -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest" "${ROOT_DIR}"
}

push() {
    log "Pushing ${IMAGE}:${TAG}"
    docker push "${IMAGE}:${TAG}"
    docker push "${IMAGE}:latest"
}

deploy() {
    : "${DEPLOY_HOST:?DEPLOY_HOST is required for deploy}"
    local target="${DEPLOY_USER}@${DEPLOY_HOST}"
    local ssh_opts=(-p "${SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

    log "Uploading compose files to ${target}:${DEPLOY_PATH}"
    # SC2029: the values are expanded locally on purpose and passed to the server
    # shellcheck disable=SC2029
    ssh "${ssh_opts[@]}" "${target}" "mkdir -p '${DEPLOY_PATH}'"
    scp -P "${SSH_PORT}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
        "${ROOT_DIR}/deploy/docker-compose.yml" "${ROOT_DIR}/deploy/prometheus.yml" \
        "${target}:${DEPLOY_PATH}/"

    log "Deploying ${IMAGE}:${TAG} on ${DEPLOY_HOST}"
    # the remote part keeps the previous tag and rolls back to it if the new container is not healthy
    # shellcheck disable=SC2029
    ssh "${ssh_opts[@]}" "${target}" \
        "DEPLOY_PATH='${DEPLOY_PATH}' IMAGE='${IMAGE}' TAG='${TAG}' bash -s" <<'REMOTE'
set -euo pipefail
cd "${DEPLOY_PATH}"

previous_tag=""
if [ -f .env ]; then
    previous_tag="$(sed -n 's/^TAG=//p' .env)"
fi

release() {
    printf 'IMAGE=%s\nTAG=%s\n' "${IMAGE}" "$1" > .env
    docker compose pull app
    docker compose up -d --remove-orphans
}

healthy() {
    for _ in $(seq 1 15); do
        if curl -fsS http://127.0.0.1/healthz > /dev/null; then
            return 0
        fi
        sleep 2
    done
    return 1
}

release "${TAG}"

if healthy; then
    echo "Release ${TAG} is healthy"
    docker image prune -f > /dev/null
    exit 0
fi

echo "Release ${TAG} failed the health check" >&2
if [ -n "${previous_tag}" ]; then
    echo "Rolling back to ${previous_tag}" >&2
    release "${previous_tag}"
fi
exit 1
REMOTE
}

case "${1:-all}" in
    build) build ;;
    push) push ;;
    deploy) deploy ;;
    all) build; push; deploy ;;
    *)
        echo "Usage: $0 [build|push|deploy|all]" >&2
        exit 2
        ;;
esac
