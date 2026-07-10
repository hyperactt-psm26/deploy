# adampsm-deploy

Master compose stack for the adamPSM app + shared infra (Postgres, Kafka, Redis, Kong,
Vault, Caddy). Expected to sit as a sibling folder to `hactt-backend`, `hactt-frontend`,
`logging_services`, `notification-services`, and `blockchain/` on the droplet, e.g.:

```
/opt/adamPSM/
  hactt-backend/
  hactt-frontend/
  logging_services/
  notification-services/
  blockchain/
    blockchain-service/
    fabric-identity-service/
    hactt-network/
    hactt-chaincode/
    scripts/
  adampsm-deploy/   <- this repo
```

See the deployment plan for the full step-by-step. Quick reference for the pieces that
live only in this repo:

## Secrets that must exist before `docker compose up` (never committed to git)

- `.env` — copy from `.env.example`, fill in `DOMAIN`, `SAGILE_DOMAIN`, `DEEPSEEK_API_KEY`,
  SMTP creds, Sagile OAuth client id/secret.
- `vault/tls/vault.crt`, `vault/tls/vault.key` — copy from the dev machine's
  `psm/vault/tls/` via `scp`.
- `vault/config/agent-token` — copy from the dev machine's `psm/vault/config/agent-token`
  via `scp`.
- `vault/data/` — copy from the dev machine's `psm/vault/data/` via `scp` if you want to
  keep the existing Vault contents (JWT signing key, wallet certs already written).
  Vault restarts **sealed** — you'll need the unseal key(s) from when it was first
  initialized to run `docker compose exec vault vault operator unseal` (repeat per key
  share) before `hactt-backend` can read/write secrets.

## One-time Kong bootstrap (after first `docker compose up -d`)

```
docker compose exec kong-gateway kong migrations bootstrap
docker compose restart kong-gateway
```

Kong's admin API is bound to `127.0.0.1:8001` only (not public) — reach it via an SSH
tunnel: `ssh -L 8001:127.0.0.1:8001 user@droplet-ip`, then from your local machine:

```
curl -i -X POST http://localhost:8001/services --data name=hactt-backend --data url=http://hactt-backend:8090
curl -i -X POST http://localhost:8001/services/hactt-backend/routes --data 'paths[]=/api' --data strip_path=true
```

Add further services/routes the same way for `blockchain-service` etc. once you know
which paths the frontend actually calls through Kong vs. directly.

## Known gaps / deliberately out of scope for this pass

- `hactt-backend`'s S3/RustFS config (`CLOUD_AWS_S3_ENDPOINT`) still points at
  `localhost:9000` — attachment upload features won't work until the `psm/s3` (RustFS)
  service is also deployed and wired in. Not part of this deployment per current scope.
- `hactt-frontend` runs in dev mode (`pnpm run dev` via `Dockerfile.dev`), matching how
  it's already been run locally. A production Vite build + static serve would be lighter
  on RAM and more appropriate for a real deployment — worth a follow-up pass.
- Only `hactt-network`'s Fabric containers + `hactt-chaincode` + `fabric-identity-service`
  + `blockchain-service` are deployed; Hyperledger Explorer and the load-test harness
  (`test-service`) are intentionally excluded.
