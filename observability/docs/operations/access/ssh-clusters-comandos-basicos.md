# Acceso SSH a clusters y comandos básicos (referencia local)

Documento de uso personal en el workspace **Mercadolibre Viena**. Resume cómo entrar por terminal a los nodos YOUR_ORG y los comandos que suelen usarse para revisar estado y reiniciar componentes de observabilidad.

**No incluir claves, contraseñas ni tokens en este archivo ni en git.** Las credenciales viven en `~/.ssh/` y en secretos de Kubernetes.

Runbooks relacionados (más detalle operativo):

- `docs/operations/runbooks/runbook-observability.md`
- `docs/operations/runbooks/runbook-post-deploy-checks.md`

---

## 1. Qué necesitás en tu máquina

| Elemento | Ubicación típica | Notas |
|----------|------------------|--------|
| Clave gateway **assembly** | `~/.ssh/assembly_gateway` | Salto público hacia la red del cluster assembly |
| Clave nodos **assembly** | `~/.ssh/assembly_access` | ProxyJump vía `assembly_gateway` |
| Clave **infra / dev** | `~/.ssh/terraform` | Gateway prod y dev |
| Config SSH | `~/.ssh/config` | Hosts `assembly_gateway`, `observability-*`, `inf-1`, etc. |

Permisos recomendados:

```bash
chmod 600 ~/.ssh/assembly_gateway ~/.ssh/assembly_access ~/.ssh/terraform
chmod 644 ~/.ssh/config
```

Probar conectividad (timeout corto):

```bash
ssh -o ConnectTimeout=10 -o BatchMode=yes observability-1 echo OK
ssh -o ConnectTimeout=10 -o BatchMode=yes inf-1 echo OK
```

---

## 2. Mapa de entornos

| Entorno | Para qué | SSH (alias en `~/.ssh/config`) | Kubernetes |
|---------|----------|--------------------------------|------------|
| **Assembly / observability** | Stack central nuevo (ArgoCD assembly, Grafana `*.observability.yourdomain.tld`, VictoriaMetrics/Logs) | `observability-1`, `observability-2`, `observability-3` | MicroK8s en cada nodo |
| **INF (legacy)** | Prometheus/Loki histórico, `*.infra.yourdomain.tld` | `inf-1` (vía `YOUR_SSH_JUMP_HOST`) | MicroK8s |
| **Dev** | Pruebas | `k8s-dev-1` (vía `YOUR_SSH_JUMP_HOST_DEV`) | MicroK8s |

**ArgoCD (UI):**

- Assembly: `https://argocd.assembly.yourdomain.tld`
- Infra (si aplica): `https://argocd.yourdomain.tld`

**Grafana (ejemplos):**

- Assembly / observability: `https://grafana.yourdomain.tld`

En MicroK8s el comando habitual es **`microk8s kubectl`** (no hace falta `kubectl` global en el nodo). Desde tu laptop podés ejecutar comandos remotos:

```bash
ssh observability-1 "microk8s kubectl get nodes"
```

Opcional: traer kubeconfig al laptop (solo si lo necesitás fuera del SSH):

```bash
ssh observability-1 "microk8s config" > /tmp/kube-assembly.config
export KUBECONFIG=/tmp/kube-assembly.config
kubectl get nodes   # requiere kubectl instalado localmente
```

---

## 3. Fragmento de referencia para `~/.ssh/config`

Ajustá IPs/usuario si el equipo las actualiza. Este bloque refleja la configuración usada en operaciones assembly:

```
Host assembly_gateway
  HostName 78.104.208.89
  User SSH_USER
  IdentityFile ~/.ssh/assembly_gateway
  IdentitiesOnly yes

Host observability-1
  HostName YOUR_K8S_NODE_IP_230
  User SSH_USER
  ProxyJump assembly_gateway
  IdentityFile ~/.ssh/assembly_access
  IdentitiesOnly yes

Host observability-2
  HostName YOUR_K8S_NODE_IP_196
  User SSH_USER
  ProxyJump assembly_gateway
  IdentityFile ~/.ssh/assembly_access
  IdentitiesOnly yes

Host observability-3
  HostName YOUR_K8S_NODE_IP_95
  User SSH_USER
  ProxyJump assembly_gateway
  IdentityFile ~/.ssh/assembly_access
  IdentitiesOnly yes

Host YOUR_SSH_JUMP_HOST
  HostName 193.171.117.61
  User SSH_USER
  IdentityFile ~/.ssh/terraform

Host inf-1
  HostName YOUR_K8S_NODE_IP
  User SSH_USER
  ProxyJump YOUR_SSH_JUMP_HOST
  IdentityFile ~/.ssh/terraform
```

---

## 4. Revisión rápida de salud (copiar/pegar)

Definí un alias mental: **`K="ssh observability-1 microk8s kubectl"`** o ejecutá los bloques completos.

### Cluster y nodos

```bash
ssh observability-1 "microk8s kubectl get nodes -o wide"
ssh observability-1 "microk8s kubectl top nodes"   # si metrics-server está OK
```

### Namespace `observability` (casi todo el stack)

```bash
ssh observability-1 "microk8s kubectl get pods -n observability -o wide"
ssh observability-1 "microk8s kubectl get pods -n observability | grep -v Running | grep -v Completed"
ssh observability-1 "microk8s kubectl get pvc -n observability"
ssh observability-1 "microk8s kubectl get events -n observability --sort-by=.lastTimestamp | tail -25"
```

### Pods con problemas (CrashLoop, reinicios)

```bash
ssh observability-1 "microk8s kubectl get pods -n observability -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,READY:.status.containerStatuses[0].ready"
```

### Logs (últimas líneas)

```bash
# Deployment (ej. blackbox-exporter, grafana, otel-collector-central)
ssh observability-1 "microk8s kubectl logs -n observability deploy/blackbox-exporter --tail=50"
ssh observability-1 "microk8s kubectl logs -n observability deploy/grafana -c grafana --tail=50"
ssh observability-1 "microk8s kubectl logs -n observability deploy/otel-collector-central --tail=50"

# Pod concreto (si el nombre cambió, listar antes con get pods)
ssh observability-1 "microk8s kubectl logs -n observability POD_NAME --tail=100"
```

### Describe (eventos del pod: FailedMount, BackOff, etc.)

```bash
ssh observability-1 "microk8s kubectl describe pod -n observability POD_NAME | tail -40"
```

### Operador Prometheus / CRDs

```bash
ssh observability-1 "microk8s kubectl get pods -n observability -l app.kubernetes.io/name=prometheus-operator"
ssh observability-1 "microk8s kubectl get crd | grep monitoring.coreos.com"
```

### Gateway API y TLS (edge)

```bash
ssh observability-1 "microk8s kubectl get httproute -n observability"
ssh observability-1 "microk8s kubectl get certificate -n envoy-gateway-system"
```

### Comprobar endpoints desde fuera (sin SSH)

```bash
curl -sI https://grafana.yourdomain.tld | head -5
curl -sI https://otel.yourdomain.tld/v1/logs | head -5   # 405 = OTLP vivo
```

---

## 5. Reinicios y recuperación (cuándo y cómo)

Preferí **`rollout restart`** en Deployments antes que borrar PVCs o StatefulSets sin runbook.

| Componente | Comando típico | Cuándo |
|------------|----------------|--------|
| Grafana | `microk8s kubectl rollout restart deployment/grafana -n observability` | Tras cambiar secret `grafana-admin`, datasource colgado |
| Blackbox exporter | `microk8s kubectl rollout restart deployment/blackbox-exporter -n observability` | Tras cambiar ConfigMap de módulos |
| OTel central | `microk8s kubectl rollout restart deployment/otel-collector-central -n observability` | Tras cambiar configmap de collector |
| Un pod atascado | `microk8s kubectl delete pod -n observability POD_NAME` | El controller recrea el pod (Deployment/RS) |

Ejemplo remoto:

```bash
ssh observability-1 "microk8s kubectl rollout restart deployment/blackbox-exporter -n observability"
ssh observability-1 "microk8s kubectl rollout status deployment/blackbox-exporter -n observability --timeout=120s"
```

**Evitar sin acuerdo:**

- Borrar PVCs de VictoriaMetrics, VictoriaLogs o Grafana (pérdida de datos).
- `scale` a 0 de Prometheus/VM sin plan de migración.
- Cambios manuales de HTTPRoute/certificados si el entorno es GitOps (ArgoCD los pisa o genera drift).

**GitOps (ArgoCD):** después de push a `observability` / `k8s-observability`, en la UI: **Refresh → Sync** en la Application `observability-central`. Si hay operación colgada: Terminate y volver a Sync.

---

## 6. Chequeos que suelen hacerse tras un deploy

Equivalente resumido de `runbook-post-deploy-checks.md`:

1. Todos los pods `Running` en `observability`.
2. HTTPRoutes `ACCEPTED=True`.
3. Certificados `Ready=True` en `envoy-gateway-system`.
4. Blackbox: pod Running y logs sin `Error loading config`.
5. Grafana: datasources Victoria Metrics / Victoria Logs responden (UI o API).

Probe blackbox desde dentro del cluster:

```bash
ssh observability-1 'microk8s kubectl exec -n observability deploy/grafana -c grafana -- \
  wget -qO- "http://blackbox-exporter:9115/probe?target=https://grafana.yourdomain.tld&module=https_2xx" 2>/dev/null | grep probe_success'
```

---

## 7. Grafana por API (org Assembly, orgId 2)

Solo si necesitás scriptear; la contraseña sale del secret, no la pegues acá.

```bash
# Usuario efectivo suele ser el del secret grafana-admin (ej. observability)
PASS="$(ssh observability-1 "microk8s kubectl get secret grafana-admin -n observability -o jsonpath='{.data.admin-password}' | base64 -d")"

curl -s -H 'X-Grafana-Org-Id: 2' --user "observability:${PASS}" \
  'https://grafana.yourdomain.tld/api/health'
```

---

## 8. INF vs Assembly: qué nodo usar

| Tarea | Nodo SSH |
|-------|----------|
| Incidente en stack **assembly** (Victoria, OTel central nuevo, blackbox assembly) | `observability-1` (cualquier nodo del cluster assembly) |
| Legacy **infra** (`*.infra.yourdomain.tld`, inf-1 concentrado) | `inf-1` |
| Validar métricas blackbox en VictoriaMetrics | Grafana + datasource `victoria-metrics`; jobs `blackbox-https`, `blackbox-otlp` |

---

## 9. Troubleshooting SSH

| Síntoma | Qué probar |
|---------|------------|
| `Permission denied (publickey)` | `IdentitiesOnly yes`, ruta correcta de `IdentityFile`, permisos 600 en la clave |
| Timeout en gateway | VPN/red YOUR_ORG; ping al `HostName` del gateway |
| `error in libcrypto` | La clave privada debe terminar en newline (`echo >> ~/.ssh/assembly_gateway`) |
| ProxyJump falla | Probar primero `ssh assembly_gateway`, luego el nodo interno |

---

## 10. Repos y cambios de configuración

| Repo | Rol |
|------|-----|
| `YOUR_ORG/assembly/observability` | Helm chart `observability-central`, dashboards, alertas |
| `YOUR_ORG/k8s-platform/clusters/k8s-observability` | Application ArgoCD (values overlay assembly) |

En el repo público, los charts viven bajo `kubernetes/charts/` y la documentación bajo `docs/` (ver `PLACEHOLDERS.md` para valores sensibles).

---

*Última actualización: referencia operativa assembly/observability (MicroK8s, blackbox, VictoriaMetrics/Logs).*
