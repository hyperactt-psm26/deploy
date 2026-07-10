#!/usr/bin/env bash
# Run this on the droplet (as root or via sudo) to prep it and pull all the repos
# into the exact folder layout the master docker-compose.yml's relative build
# contexts and volume mounts expect. See README.md for the manual steps that
# still have to happen after this script (secrets, Fabric network bring-up,
# kong bootstrap, etc).
set -euo pipefail

# Requires the droplet's SSH key to already be added to the hyperactt GitHub
# account (which has access to every repo in the org) - see deploy/README.md.
# `ssh -T git@github.com` always exits non-zero (GitHub refuses shell access
# even on successful auth), so capture its output first rather than checking
# the pipeline's exit status directly - otherwise `pipefail` above trips this
# check even when auth actually succeeded.
github_auth_output="$(ssh -T git@github.com 2>&1 || true)"
echo "$github_auth_output" | grep -qi "successfully authenticated" \
  || { echo "git@github.com SSH auth isn't working yet - set that up first (see README.md)" >&2; echo "$github_auth_output" >&2; exit 1; }

ORG="hyperactt-psm26"
BASE_DIR="/opt/adamPSM"

clone() {
  local repo="$1" dest="$2"
  if [ -d "$dest/.git" ]; then
    git -C "$dest" pull --ff-only
  else
    git clone "git@github.com:${ORG}/${repo}.git" "$dest"
  fi
}

echo "==> Docker"
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
docker compose version >/dev/null

echo "==> Swapfile (safety net on a memory-constrained box)"
if ! swapon --show | grep -q .; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> Firewall (22/80/443 only)"
if command -v ufw &>/dev/null; then
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable
fi

echo "==> Cloning repos into $BASE_DIR"
mkdir -p "$BASE_DIR/blockchain"

clone hactt-backend            "$BASE_DIR/hactt-backend"
clone hactt-frontend           "$BASE_DIR/hactt-frontend"
clone logging-services         "$BASE_DIR/logging_services"
clone notification-service     "$BASE_DIR/notification-services"
clone SAgileHyperagile          "$BASE_DIR/SAgileHyperagile"
clone blockchain-service        "$BASE_DIR/blockchain/blockchain-service"
clone identity-service          "$BASE_DIR/blockchain/fabric-identity-service"
clone hactt-network             "$BASE_DIR/blockchain/hactt-network"
clone hactt-chaincode           "$BASE_DIR/blockchain/hactt-chaincode"
clone bash-scripts              "$BASE_DIR/blockchain/scripts"
clone deploy                    "$BASE_DIR/deploy"

echo
echo "Done. Remaining manual steps (not safe to script - see $BASE_DIR/deploy/README.md):"
echo "  1. scp vault/tls/, vault/config/agent-token, and (optionally) vault/data/"
echo "     from your dev machine's psm/vault/ into $BASE_DIR/deploy/vault/"
echo "  2. scp $BASE_DIR/deploy/hactt-backend-application.yaml.template to"
echo "     $BASE_DIR/hactt-backend/src/main/resources/application.yaml"
echo "     (it's gitignored in that repo on purpose - never committed)"
echo "  3. cp $BASE_DIR/deploy/.env.example $BASE_DIR/deploy/.env and fill in real secrets"
echo "  4. cd $BASE_DIR/blockchain/hactt-network && ./network.sh up createChannel"
echo "  5. Package/install/approve chaincode via $BASE_DIR/blockchain/scripts, then"
echo "     cd $BASE_DIR/blockchain/hactt-chaincode && docker compose up -d"
echo "  6. cd $BASE_DIR/deploy && docker compose up -d --build"
echo "  7. docker compose exec kong-gateway kong migrations bootstrap && docker compose restart kong-gateway"
echo "  8. cd $BASE_DIR/SAgileHyperagile && docker compose up -d --build"
