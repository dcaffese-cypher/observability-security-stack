# Security Observability Blueprint (Kubernetes)

Production-grade security architecture aligned to the current observability stack (`Prometheus`, `Grafana`, `Loki`, `OpenTelemetry`) in namespace `observability`.

---

## 1. Decision and scope

For this cluster, prioritize a cloud-native approach:

- **Runtime threat detection:** `Falco`
- **Vulnerability and misconfiguration scanning:** `Trivy Operator`
- **Admission/policy guardrails:** `Kyverno`
- **Correlation and alerting:** `Loki` + `Grafana Alerting` (+ optional Prometheus metrics)

For Kubernetes-first operations this stack reduces operational overhead and integrates directly with the existing platform.

---

## 2. Target architecture

### 2.1 Data and control flow

1. Workloads and nodes generate runtime events.
2. `Falco` detects suspicious behavior (container escape patterns, crypto miners, shell in container, privileged misuse).
3. `Trivy Operator` continuously scans images, workloads, and cluster configs, producing CRDs and Kubernetes events.
4. `Kyverno` enforces preventive policy at admission time (deny or audit).
5. Security events are centralized in `Loki`.
6. `Grafana` dashboards and alert rules provide triage and notification.
7. Runbooks drive incident response: detect -> scope -> contain -> recover.

### 2.2 Namespaces and boundaries

- `security`: Falco, Trivy Operator, Kyverno
- `observability`: Prometheus, Loki, Grafana, OTel

Use dedicated service accounts and namespace-scoped RBAC where possible. Keep cluster-wide permissions only for components that require them (Falco DaemonSet, policy engine controllers, vulnerability scanner controllers).

---

## 3. Reference deployment (Helm)

> Run from an operator host with cluster access (`kubectl` / `microk8s kubectl` and Helm available).

```bash
# 1) Add repositories
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# 2) Namespace
kubectl create namespace security --dry-run=client -o yaml | kubectl apply -f -

# 3) Falco (runtime)
helm upgrade --install falco falcosecurity/falco \
  -n security \
  --set falco.jsonOutput=true \
  --set falco.logStderr=true \
  --set driver.kind=modern_ebpf

# 4) Trivy Operator (vuln + config scan)
helm upgrade --install trivy-operator aqua/trivy-operator \
  -n security \
  --set serviceMonitor.enabled=true

# 5) Kyverno (policy)
helm upgrade --install kyverno kyverno/kyverno \
  -n security \
  --set admissionController.replicas=2
```

### 3.1 Recommended hardening defaults

- Pin chart versions explicitly in production pipelines.
- Configure Pod Security Standards (`restricted`) for application namespaces.
- Use `NetworkPolicy` to minimize east-west traffic.
- Enforce image provenance/signing policies (Kyverno + Cosign).
- Keep Falco and Trivy rules/policies in Git and deploy via GitOps.

---

## 4. Integrating with observability-central

### 4.1 Loki ingestion for security events

Primary objective: all relevant security events must be queryable in Grafana Explore and alertable from Grafana Alerting.

- Ship Falco events to Loki (via Falco outputs or a sidekick/forwarder depending on environment standard).
- Keep stable labels for correlation:
  - `cluster`
  - `namespace`
  - `pod`
  - `container`
  - `rule`
  - `priority`
  - `source=falco|trivy|kyverno`

### 4.2 Prometheus metrics

- Enable `ServiceMonitor` where supported (`trivy-operator` and security controllers when available).
- Create security SLO metrics and alerts:
  - Critical runtime alerts rate
  - Open critical vulnerabilities count
  - Policy violation trend by namespace

### 4.3 Grafana

- Add a Security Overview dashboard:
  - Runtime incidents by severity and namespace
  - Top violated policies
  - Vulnerabilities by severity/image/workload
- Add drill-down panels to pivot from namespace -> pod -> logs.

---

## 5. Baseline policies (Kyverno)

Start with these cluster policies in `audit` mode, then move to `enforce` progressively:

- Block privileged containers
- Require `runAsNonRoot: true`
- Drop all capabilities by default
- Disallow hostPath mounts (unless approved)
- Restrict `latest` image tags
- Require resource requests/limits
- Require trusted registries

Promote policy gates namespace by namespace to avoid deployment disruption.

---

## 6. Roadmap 30 / 60 / 90 days

### Day 0-30 (foundation)

- Deploy `Falco`, `Trivy Operator`, `Kyverno` in `security` namespace.
- Enable security event ingestion to `Loki`.
- Publish first Grafana security dashboard and alert rules.
- Create operational runbook for triage and containment.

### Day 31-60 (stabilization)

- Roll out Kyverno baseline policies (`audit` -> selective `enforce`).
- Tune Falco rules to reduce false positives.
- Add vulnerability remediation SLAs by severity.
- Integrate on-call notifications (Slack/Email/Webhook) with escalation.

### Day 61-90 (maturity)

- Enforce image signing/provenance.
- Define namespace risk score (runtime + vuln + policy posture).
- Add periodic security posture reports in Grafana.
- Run tabletop incident simulations and measure MTTR.

---

## 7. Operational risks and mitigations

- **Noise flood in alerts:** start with conservative rules and tune by environment.
- **Performance impact:** set resource requests/limits and monitor daemon/controller overhead.
- **Policy rollout regressions:** begin with `audit` mode and phased `enforce`.
- **Data retention growth (Loki):** review retention and labels cardinality to control cost.

---

## 8. Minimum acceptance criteria

- Runtime detections visible in Grafana within 1 minute.
- Critical vulnerability findings visible and alertable.
- Baseline admission policies active in at least one production namespace.
- Security on-call runbook tested with one simulated incident.
