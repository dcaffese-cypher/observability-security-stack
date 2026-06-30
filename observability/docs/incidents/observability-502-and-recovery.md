# Observability 502 and recovery

## What happened

After running the demo cleanup script (scale down → wipe Loki/Prometheus/VM data → scale up), Grafana started returning **502 Bad Gateway** when accessed via https://grafana.yourdomain.tld (APISIX ingress). The observability workloads themselves are **healthy** (Grafana, Prometheus, Loki, Victoria Metrics, OTel all Running and responding inside the cluster).

## Root cause

- **502:** The APISIX gateway was likely using a **cached upstream** (old Grafana pod IP). After the script restarted Grafana, the pod got a new IP; the gateway had not refreshed the backend → 502.
- **Current state:** APISIX gateway pods are stuck in **Init** waiting for **etcd** (`inf-apisix-etcd`). The etcd cluster for APISIX is unstable (restarts / CrashLoopBackOff). This is **shared infrastructure**, not part of the observability Helm release.

## What was done

1. Checked pods and services in `observability`: all Running.
2. Confirmed Grafana health from inside the cluster (e.g. `curl http://grafana.observability:80/` → 302).
3. Recreated the Grafana Ingress to force the controller to resync.
4. Restarted the APISIX ingress controller.
5. Restarted the APISIX gateway deployment; deleted the serving gateway pod to force config reload.
6. After that, **no APISIX gateway pod is Ready** (all waiting on etcd), so external access via ingress is currently down until APISIX/etcd is fixed by the infra team.

## Workaround: access Grafana without ingress

From a machine that can reach the cluster (e.g. `inf-1` with MicroK8s or your laptop with kubeconfig):

```bash
# Port-forward Grafana to localhost (then open http://localhost:3000). On MicroK8s (e.g. inf-1):
microk8s kubectl port-forward -n observability svc/grafana 3000:80
```

Then open **http://localhost:3000** in the browser. Use the Grafana credentials you have (or recover from the secret as in the runbook).

## What you need from infra

- **APISIX etcd** (`inf-apisix-etcd-*`) must be stable and ready so that APISIX gateway pods can leave Init and become Ready.
- Once the gateway is back, the ingress controller will have pushed current backends (Grafana service endpoints), so https://grafana.yourdomain.tld should work again.

## Script change to avoid similar issues

The cleanup script **scales down** Loki, Prometheus, and Victoria Metrics and then scales them back up. That can change pod IPs and trigger 502 if the gateway does not refresh backends quickly. To reduce risk in demo:

- Consider **not** scaling down/up in the script; only wipe data when you can afford a short outage or will refresh the ingress/gateway.
- Or run the script outside peak times and, after it runs, restart the APISIX ingress controller (or gateway) so it picks up new endpoints.

Repository: `YOUR_ORG/clusters/k8s-infra/Repository/observability-central`
