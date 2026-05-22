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
- `test/smoke-test.sh` — release smoke test (boot, recursive DNS, DNSSEC, admin UI)
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

Automated smoke test: `test/smoke-test.sh <image-ref>` boots the image, waits for readiness, and asserts:

1. Container in `running` state, no fatal markers in logs.
2. Unbound listens on `127.0.0.1:5335` inside the container.
3. Recursive resolution: `dig @127.0.0.1 example.com` and `cloudflare.com` return `NOERROR` with answers.
4. DNSSEC validating: `dig +dnssec cloudflare.com` returns the `ad` flag.
5. DNSSEC enforcing: `dnssec-failed.org` returns `SERVFAIL`.
6. Admin UI at `/admin/` responds 2xx/3xx.

Local run:

```bash
docker build -t pihole-smoke docker/
./test/smoke-test.sh pihole-smoke
```

In CI, `pr-docker-image.yml` runs the script against the just-built PR image (job `smoke-test (amd64)`) after the multi-arch build. Renovate auto-merge for `pihole/pihole` bumps must wait on this check.

## CI gates

`main` is protected via a GitHub Repository Ruleset committed to the repo at `.github/rulesets/main.json`. It requires two status checks before any merge — including Renovate auto-merge of `pihole/pihole` bumps:

- `build-and-push-pr-image` — multi-arch build succeeds.
- `smoke-test (amd64)` — runtime smoke test passes.

Renovate uses GitHub's native auto-merge (`"platformAutomerge": true` on the `pihole/pihole` rule in `renovate.json`), so a failing smoke test hard-blocks the merge instead of merely delaying Renovate's polling.

Apply / update the ruleset (one-shot, then on every edit to the JSON):

```bash
# First-time apply
gh api -X POST repos/:owner/:repo/rulesets \
  --input .github/rulesets/main.json

# Update after editing the JSON
RULESET_ID=$(gh api repos/:owner/:repo/rulesets --jq '.[] | select(.name=="main-branch-protection") | .id')
gh api -X PUT "repos/:owner/:repo/rulesets/${RULESET_ID}" \
  --input .github/rulesets/main.json
```

Scope of auto-merge: only `pihole/pihole` Docker tag bumps are auto-merged. All other Renovate-managed dependencies default to `automerge: false` and require manual review.

Note: classic branch protection on `main` was intentionally removed in favor of this committed ruleset. Do **not** re-enable classic branch protection — its `required_approving_review_count: 1` clashes with the solo-maintainer model (GitHub forbids self-approval) and deadlocks every PR. The ruleset alone enforces no-deletion, no-force-push, PR-required, and the two required checks.
