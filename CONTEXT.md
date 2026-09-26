# Pi-hole + Unbound Image

A single container image bundling Pi-hole with a local recursive Unbound resolver.

## Language

**Pi-hole version**:
The release version of the upstream `pihole/pihole` base image this image is built from.
_Avoid_: image version

**Unbound version**:
The version of the Alpine `unbound` package installed in the image, including Alpine's package revision (e.g. `1.25.2-r2`).
_Avoid_: upstream Unbound version (that is NLnet Labs' release number, which Alpine does not bump for backports)

**Backported fix**:
A security fix Alpine applies to an older upstream Unbound release by bumping only the package revision.

**Rebuild**:
A publish of the image with an unchanged **Pi-hole version**, done to pick up a newer **Unbound version**.
_Avoid_: release, bump

**Scheduled rebuild**:
A **Rebuild** triggered on a fixed timer rather than by a change to the repo.

**Floating tag**:
An image tag that a **Rebuild** moves to the new image: `latest` and the bare **Pi-hole version**.
_Avoid_: moving tag, version tag

**Exact tag**:
An image tag naming exactly one pair of **Pi-hole version** and **Unbound version**, e.g. `2026.09.0-unbound1.25.2-r2`. Never overwritten.
_Avoid_: build tag, pinned tag, immutable tag

## Relationships

- An image is identified by one **Pi-hole version** and one **Unbound version**
- A **Rebuild** changes the **Unbound version** but never the **Pi-hole version**
- A **Backported fix** changes the **Unbound version** without changing the upstream Unbound release number
- Every published image carries exactly one **Exact tag** and one GitHub Release of the same name
- A **Scheduled rebuild** publishes only when its **Exact tag** does not exist yet
