# Phase 3 & 4 – ArgoCD Integration Plan

**Date:** 2026-02-19  
**Status:** Pending (requires Sean / GitLab admin access)  
**Repo:** `https://git.yourdomain.tld/YOUR_ORG/assembly/observability`

**Updates (Sean alignment):** Repo add via ArgoCD UI (Settings → Repositories); use group token `MANUAL_GITLAB_TOKEN` from https://git.yourdomain.tld/groups/YOUR_ORG/assembly/-/settings/ci_cd#ci-variables. Use a **single** ArgoCD Application for the observability-central chart (see `kubernetes/gitops/applications/observability-central-app.yaml`). Certificates live in `kubernetes/gitops/` and are **not** managed by ArgoCD (apply from k8s-infra).

---

## What was done in Phase 1 & 2

| Phase | What | Status |
|-------|------|--------|
| Phase 1 | Repo structure: `kubernetes/charts/observability-central`, `kubernetes/charts/observability-edge`, `kubernetes/gitops/` (single Application + TLS manifests), `ansible/otel-agent/`, `docs/` | Done |
| Phase 2 | Applied CRDs to cluster (Cert-Manager Certificates + ApisixTls for Grafana and OTel) | Done |

---

## Phase 3 – Register the repo in ArgoCD

### What this does
ArgoCD needs to know about our repository so it can pull the Helm charts and Application YAMLs from it.  
Currently ArgoCD only knows about `k8s-infra`. Our `assembly/observability` repo is not registered.

### Steps (requires cluster access on inf-1)

```bash
# 1. Log in to ArgoCD CLI (run from inf-1 or any machine with kubectl access)
argocd login argocd.yourdomain.tld \
  --username admin \
  --password <argocd-admin-password> \
  --grpc-web

# 2. Register the observability repo using the Deploy Token
argocd repo add https://git.yourdomain.tld/YOUR_ORG/assembly/observability.git \
  --username <deploy-token-username> \
  --password <deploy-token-value> \
  --name observability

# 3. Verify the repo is listed and shows "Successful"
argocd repo list
```

### What we need from Sean / GitLab admin

| Item | Why needed | How to get it |
|------|-----------|---------------|
| **GitLab Deploy Token** (read_repository scope) | ArgoCD uses it to clone the repo | GitLab → `YOUR_ORG/assembly/observability` → Settings → Repository → Deploy Tokens → Create token with `read_repository` scope. GitLab shows the token **only once**. |
| **ArgoCD admin password** | To run `argocd login` | Sean has it, or it can be read from the cluster: `microk8s kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" \| base64 -d` |

> **Note:** A **Feed Token** (`glft-…` from GitLab user settings) is not a Deploy Token and does not work for repo clone in Argo CD. Create a Deploy Token with `read_repository` instead.

---

## Phase 4 – Apply the single ArgoCD Application

### What this does
We use **one** ArgoCD Application that deploys the **observability-central** Helm chart (which includes Prometheus, Grafana, Loki, Victoria Metrics, OTel Collector via dependencies and templates). No separate Applications per component.

The Application YAML is in the repo: **`kubernetes/gitops/applications/observability-central-app.yaml`**. Sean will move this (and the TLS manifests) to k8s-infra and apply at the point of install.

### Apply it (from k8s-infra or a machine with cluster access)

```bash
# Apply the single Application (after the observability repo is registered in ArgoCD)
microk8s kubectl apply -f kubernetes/gitops/applications/observability-central-app.yaml -n argocd
```

Or create via ArgoCD UI: New App, point to repo `https://git.yourdomain.tld/YOUR_ORG/assembly/observability.git`, path `observability/kubernetes/charts/observability-central`, destination namespace `observability`, project `admin`.

### Verify

```bash
argocd app list
argocd app get observability-central

# Or via kubectl (MicroK8s: microk8s kubectl)
microk8s kubectl get application observability-central -n argocd
```

---

## Important: what happens to the existing Helm release?

The stack is currently deployed via `helm upgrade` (manual). When ArgoCD takes over:

1. ArgoCD will **detect the existing resources** and adopt them (no re-creation if values match).
2. If there are diffs, ArgoCD will show them in the UI before syncing.
3. **Recommended:** first sync with `prune: false` and `selfHeal: false` (already set), review diffs in ArgoCD UI, then enable `selfHeal: true`.
4. The Grafana admin secret is created by the Grafana subchart; when ArgoCD adopts the release, that secret remains part of the chart’s resources.

---

## Summary of what we need from Sean

| # | What | Urgency |
|---|------|---------|
| 1 | **GitLab Deploy Token** for `YOUR_ORG/assembly/observability` with `read_repository` scope | Required for Phase 3 |
| 2 | **ArgoCD admin password** (or delegate access) | Required for Phase 3 |
| 3 | Confirm ArgoCD project `admin` can deploy to `observability` namespace | Should be fine (broad permissions confirmed), but good to verify |
| 4 | Review MR `feat/observability-central-stack` and merge when ready | Needed before Phase 4 (ArgoCD reads from `main`/`HEAD`) |

---

## Quick reference: current ArgoCD state

- ArgoCD URL: `https://argocd.yourdomain.tld`
- ArgoCD namespace: `argocd`
- ArgoCD project: `admin` (has broad cluster permissions)
- Registered repos (as of last check): only `k8s-infra` — **observability repo NOT yet registered**
- Existing Applications: none for observability namespace
