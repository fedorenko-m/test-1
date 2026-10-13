#!/usr/bin/env bash
set -euo pipefail

case "$1" in
    build)
        echo "Building image: ${IMAGE}:${TAG}"
        docker build -t "${IMAGE}:${TAG}" .
        ;;
    push)
        echo "Pushing image: ${IMAGE}:${TAG}"
        docker push "${IMAGE}:${TAG}"
        ;;
    deploy)
        echo "Deploying to ${DEPLOY_HOST}..."
        
        ssh -o StrictHostKeyChecking=no "${DEPLOY_USER}@${DEPLOY_HOST}" "mkdir -p ~/app"
        scp docker-compose.yml prometheus.yml "${DEPLOY_USER}@${DEPLOY_HOST}:~/app/"
        
        ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << EOF
          cd ~/app
          echo "IMAGE=${IMAGE}" > .env
          echo "TAG=${TAG}" >> .env
          docker compose pull
          docker compose up -d --remove-orphans
          docker system prune -f
EOF
        echo "Deployment done!"
        ;;
    *)
        echo "Usage: $0 {build|push|deploy}"
        exit 1
        ;;
esac