# Pi-hole + Unbound Docker Image

Drop-in self-hosted Pi-hole + Unbound DNS image for home/SOHO users. Maintained successor of `cbcrowe/pihole-unbound`.

## Stack

- Base: `pihole/pihole` (Alpine); Unbound installed via `apk`
- Shell entrypoint (`/bin/sh`), s6 init inherited from upstream
- CI: GitHub Actions multi-arch buildx (`linux/amd64`, `386`, `arm/v6`, `arm/v7`, `arm64`), cosign signing
- Dep updates: Renovate (`renovate.json`)

## Project Structure

- `docker/` — `Dockerfile`, `custom-entrypoint.sh`, Unbound + lighttpd + dnsmasq configs
- `example/compose.yaml` — reference Docker Compose for end users
- `.github/workflows/` — `docker-publish.yml` (main) and `pr-docker-image.yml` (PRs)

## Commands

```bash
docker build -t pihole-unbound docker/                # Build image from docker/ context
docker compose -f example/compose.yaml up -d          # Smoke-test bring-up
docker compose -f example/compose.yaml down -v        # Tear down + drop volumes
dig @127.0.0.1 -p 53 example.com                      # Verify DNS resolution
```

## Gotchas

- **Publish workflow path filter**: `.github/workflows/docker-publish.yml` triggers only on changes to `docker/Dockerfile`. Edits to `custom-entrypoint.sh`, `unbound-pihole.conf`, `lighttpd-external.conf`, or `99-edns.conf` will NOT publish a new image until the next Dockerfile bump. Warn the user when editing those files. Never widen the path filter without explicit approval; instead flag the situation and let the user decide.
- **`docker/unbound-pihole.conf` mirrors the upstream Pi-hole guide** (https://docs.pi-hole.net/guides/unbound/). Treat it as a near-verbatim copy. Do not restructure or "optimize" it; only deviate when the user requests a specific change with a stated reason.

## Out of Scope

- `pihole/pihole:` tag on `docker/Dockerfile:1` — Renovate-managed. Never bump manually; wait for the bot's PR or ask the user to trigger one.

## Approval Required

- `git push` to `main` and any merge into `main`. Feature branches and PRs may proceed without confirmation.

## Testing

No automated test suite. Verify changes by:

1. `docker build docker/` succeeds locally.
2. Bring up `example/compose.yaml`; `dig @127.0.0.1 -p 53 example.com` returns an answer.
3. Pi-hole admin UI loads on the configured port.

`pr-docker-image.yml` runs multi-arch builds as a final gate; a green PR build is necessary but not sufficient.
