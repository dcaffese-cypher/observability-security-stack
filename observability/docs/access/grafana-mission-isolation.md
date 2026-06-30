# Grafana organisation per YOUR_ORG mission — Technical Design

## Overview

We operate **one Grafana organisation per YOUR_ORG mission** to isolate dashboards, folders and permissions.
Authentication is GitHub OAuth (`auth.github`) against the `YOUR_GITHUB_ORG` GitHub organisation.

**Role model constraint:** only `Admin` and `Viewer`.

**Target outcome (Sean):**
- **Admin in your own mission org**
- **Viewer across all other mission orgs**

We additionally use a primary shared org **`YOUR_ORG`** (org id=1) as the default landing org.

---

## Architecture

- **GitHub OAuth login** (Grafana `auth.github`)
  - `allowed_organizations: ["YOUR_GITHUB_ORG"]` blocks non-YOUR_ORG users
  - `org_mapping` assigns org memberships + roles on every login
- **Organisation bootstrap** (Helm hook Job)
  - Grafana OSS cannot create orgs via provisioning files
  - A Helm `post-install/post-upgrade` Job creates the 5 mission orgs idempotently via the Grafana admin API

---

## Organisations

- `YOUR_ORG` (org id=1)
  - Primary shared org (global dashboards / shared folders)
  - Renamed from the default “Main Org.” to avoid spaces in org names (Grafana parses `org_mapping` as space-separated tokens).

Mission orgs (created by bootstrap Job):
- `Assembly`
- `Access`
- `Application`
- `Cloud`
- `Conversion`

---

## Mapping matrix (GitHub Team → Grafana Org → Role)

This mapping is implemented in `kubernetes/charts/observability-central/values.yaml` under `grafana.ini.auth.github.org_mapping`.

### Baseline (applies to all authenticated users)

- `*:YOUR_ORG:Viewer`
- `*:Access:Viewer`
- `*:Application:Viewer`
- `*:Assembly:Viewer`
- `*:Cloud:Viewer`
- `*:Conversion:Viewer`

### Mission elevation (Admin in your own org)

- `@YOUR_GITHUB_ORG/assembly:YOUR_ORG:Admin` (platform team remains Admin in shared org)
- `@YOUR_GITHUB_ORG/assembly:Assembly:Admin`
- `@YOUR_GITHUB_ORG/access:Access:Admin`
- `@YOUR_GITHUB_ORG/application:Application:Admin`
- `@YOUR_GITHUB_ORG/cloud:Cloud:Admin`
- `@YOUR_GITHUB_ORG/conversion:Conversion:Admin`

---

## Access policy and fallback behaviour

- **Login gate:** only members of GitHub org `YOUR_GITHUB_ORG` may authenticate.
- **Mission membership:** controlled by GitHub team membership.
- **Fallback:** an authenticated `YOUR_GITHUB_ORG` user with no mission team still gets Viewer across orgs via the `*:<Org>:Viewer` baseline.

### Important limitation: Server Admin

Grafana **Server Admin** (global admin) is not cleanly derived from GitHub teams in Grafana OSS.
Operationally, we grant Server Admin to agreed Assembly operators **manually via Admin API/UI** after their first login.

---

## Manual prerequisites (secrets)

These must exist in the cluster (namespace `observability`). They are **not** stored in Git:

- `grafana-secret`
  - `GF_AUTH_GITHUB_CLIENT_ID`
  - `GF_AUTH_GITHUB_CLIENT_SECRET`
  - `GF_AUTH_GENERIC_OAUTH_CLIENT_ID`
  - `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET`
  - Source: Bitwarden → `Observability / Grafana OIDC Client`
  - Template: `kubernetes/charts/observability-central/manifests/grafana-secret.example.yaml`

- `grafana-admin`
  - `admin-user`
  - `admin-password`
  - Used by the bootstrap Job and for admin API calls

---

## Implementation artifacts

- `kubernetes/charts/observability-central/values.yaml`
  - `envFromSecret: grafana-secret`
  - `initChownData.enabled: false` (PVC chown workaround)
  - `grafana.ini.auth.github` + `org_mapping`

- `kubernetes/charts/observability-central/templates/grafana-org-bootstrap.yaml`
  - Helm hook Job (idempotent org creation)

---

## Verification checklist

1. Visit `https://grafana.yourdomain.tld` → GitHub login button is present.
2. Login with an Assembly member → can switch orgs; Admin in `Assembly`; Admin in `YOUR_ORG`.
3. Login with a non-Assembly mission member (e.g. Application) → Admin in their mission org; Viewer in others.
4. Login with non-`YOUR_GITHUB_ORG` user → access denied.
5. Confirm orgs exist: Grafana Admin → Organisations shows `YOUR_ORG` + 5 mission orgs.

Operational note: PVC is `ReadWriteOnce`. During rollouts, if a new Grafana pod is scheduled on a different node,
Kubernetes may show a Multi-Attach error. Deleting the old pod releases the PVC so the new pod can start.
