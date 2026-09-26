# Weekly scheduled rebuild tracks the Unbound version, unpinned

## Context

The image installs Unbound from Alpine's package repository with no version pin, so the **Unbound
version** is whatever Alpine ships at build time. The publish workflow runs only when
`docker/Dockerfile` changes, which in practice means a Renovate bump of the **Pi-hole version**.
Upstream `pihole/pihole` pins its Alpine base by digest and releases irregularly, roughly monthly.

CVE-2026-81642 (CVSS 9.1, Unbound up to 1.26.0) reached Alpine 3.24 as a **Backported fix** in
`1.25.2-r2` on 2026-09-18. The image shipped it only because a Pi-hole bump happened two days
later. Without that coincidence, a patched package would have sat unshipped until the next Pi-hole
release ([#371](https://github.com/mpgirro/docker-pihole-unbound/issues/371)).

## Decision

1. **A weekly Scheduled rebuild picks up the current Unbound version; the Dockerfile keeps Unbound
   unpinned.** Alpine keeps only the newest package revision per branch, so a pin fails the build
   from the moment Alpine moves on until someone bumps it. A timer bounds the delay between an
   Alpine fix and a published image to about a week without any build ever breaking. Impact: the
   publish workflow gains a `schedule` trigger next to the Dockerfile path filter; the path filter
   itself stays unchanged. The workflow passes the current **Unbound version** to the build, so a
   changed package misses the layer cache instead of reusing the old install.

2. **Every published image carries one Exact tag and one GitHub Release of the same name, next to
   the Floating tags.** A **Rebuild** overwrites `latest` and the bare **Pi-hole version**, so those
   tags no longer identify one image. The **Exact tag** `<pihole-version>-unbound<unbound-version>`
   includes Alpine's package revision, because a **Backported fix** changes only the revision.
   Impact: users pinned to a Floating tag receive Unbound fixes without changing their setup; users
   who need a fixed image pin the Exact tag. New releases and git tags follow the Exact tag;
   existing releases keep their bare Pi-hole names.

3. **A Scheduled rebuild publishes only when its Exact tag does not exist yet.** An unchanged week
   would otherwise produce a new digest, a new signature and a rewritten release for identical
   content. Impact: a Scheduled rebuild reacts to Unbound changes only, not to other Alpine package
   updates, which remain the job of the Pi-hole release. A Dockerfile push or a manual run always
   publishes.

4. **Every publish passes the smoke test before any push.** A Scheduled rebuild reaches `latest`
   without a pull request, so the pull request's smoke-test gate never sees it. Impact: the
   publish workflow builds and tests the amd64 image before the multi-arch push, on every trigger.

## Rejected Options

- **Pin Unbound in the Dockerfile and let Renovate bump it** - rejected because Alpine drops the
  previous revision on each update, so the build fails until the Renovate pull request merges.
- **Rebuild only on Pi-hole bumps** - rejected because the delay for a security fix depends on an
  unrelated upstream release cadence.
- **Manual rebuild when an advisory appears** - rejected because it depends on the maintainer
  noticing the advisory.
- **Install Unbound from Alpine edge or build from source** - rejected because Alpine backports
  security fixes to the stable branch, and Alpine does not support mixing edge packages into a
  stable base.
- **Suffix-only rebuild tags without overwriting Floating tags** - rejected because users on
  `latest` or a Pi-hole version would never receive the fix.
