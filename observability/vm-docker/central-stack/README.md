# OpenTelemetry Collector Master - Observability Stack

A complete observability stack deployment using Docker Compose, featuring OpenTelemetry Collector, Prometheus, Loki, and Grafana for centralized metrics, logs, and traces collection.

## 🏗️ Architecture Overview

This master deployment provides:

- **OpenTelemetry Collector**: Central collection point for metrics, logs, and traces from agents
- **Prometheus**: Time-series database for metrics storage and querying
- **Loki**: Log aggregation system for centralized log storage
- **Grafana**: Visualization and alerting platform
- **SNMP Exporter**: Network device monitoring via SNMP
- **Reverse Proxy**: Nginx for secure access (optional)

## 📋 Prerequisites

- Docker ≥ 20.10
- Docker Compose plugin ≥ 2.0
- Minimum 5 GB free disk space for initial Loki data
- Firewall ports open (if accessed externally):
  - `3000` - Grafana
  - `3100` - Loki
  - `9090` - Prometheus
  - `4317` - OTLP gRPC
  - `4318` - OTLP HTTP
  - `80/443` - Reverse Proxy (if configured)

## 🚀 Quick Start

### 1. Prepare Loki Data Directory

Create and configure the Loki data directory:

```bash
# Create bind-mount directory for Loki + WAL
mkdir -p ./loki-data/wal

# Grant ownership to Loki UID 10001
sudo chown -R 10001:10001 ./loki-data
```

### 2. Configure Environment Variables

Edit `docker-compose.yml` and update the following:

- **Grafana URL**: Replace `YOUR_GRAFANA_DOMAIN_OR_IP` with your domain or IP
- **SMTP Configuration**: Update email settings for Grafana alerts:
  ```yaml
  - GF_SMTP_USER=your-email@example.com
  - GF_SMTP_PASSWORD=your-smtp-app-password
  - GF_SMTP_FROM_ADDRESS=your-email@example.com
  ```

### 3. Configure Prometheus Targets

Edit `prometheus.yml` and replace SNMP device IPs:

```yaml
static_configs:
  - targets:
      - SNMP_DEVICE_1_IP
      - SNMP_DEVICE_2_IP
      - SNMP_DEVICE_3_IP
      - SNMP_DEVICE_4_IP
```

### 4. Start Services

```bash
# Pull images and start all services
docker compose up -d

# Verify all containers are running
docker compose ps
```

### 5. Access Services

- **Grafana**: http://YOUR_GRAFANA_DOMAIN_OR_IP:3000
  - Default credentials: `admin` / `admin` (change on first login)
- **Prometheus**: http://YOUR_GRAFANA_DOMAIN_OR_IP:9090
- **Loki**: http://YOUR_GRAFANA_DOMAIN_OR_IP:3100

## 📊 Service Details

### OpenTelemetry Collector

- **Image**: `otel/opentelemetry-collector-contrib:0.131.0`
- **Ports**: 
  - `4317` - OTLP gRPC
  - `4318` - OTLP HTTP
  - `8888` - Internal metrics
  - `13133` - Health check
- **Function**: Receives telemetry from agents and forwards to Prometheus (metrics) and Loki (logs)

### Prometheus

- **Image**: `prom/prometheus:v3.5.0`
- **Port**: `9090`
- **Retention**: 7 days (configurable)
- **Storage**: Docker volume `prometheus-data`
- **Features**: 
  - OTLP receiver enabled
  - SNMP scraping via snmp-exporter

### Loki

- **Image**: `grafana/loki:3.5.1`
- **Port**: `3100`
- **Retention**: 7 days (168h)
- **Storage**: Local directory `./loki-data`
- **Schema**: TSDB v13

### Grafana

- **Image**: `grafana/grafana:12.1.0`
- **Port**: `3000`
- **Features**:
  - OpenTelemetry datasource plugin
  - Pre-configured datasources (Prometheus, Loki)
  - Alerting rules provisioning
  - SMTP notifications

### SNMP Exporter

- **Image**: `prom/snmp-exporter`
- **Port**: `9116`
- **Function**: Exposes SNMP metrics for Prometheus scraping

## 🔧 Configuration Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Service definitions and dependencies |
| `otelcol-config.yaml` | OpenTelemetry Collector pipeline configuration |
| `prometheus.yml` | Prometheus scrape targets and rules |
| `loki-config.yml` | Loki storage and retention configuration |
| `grafana/provisioning/` | Grafana datasources and alerting rules |

## 📈 Data Flow

```
Agents → OTLP (gRPC/HTTP) → OpenTelemetry Collector
                                    ↓
                    ┌───────────────┴───────────────┐
                    ↓                               ↓
            Prometheus (Metrics)            Loki (Logs)
                    ↓                               ↓
                    └───────────────┬───────────────┘
                                    ↓
                              Grafana (Visualization)
```

## 🔍 Verification

### Check Container Status

```bash
docker compose ps
```

All services should show `Up` status.

### Verify OTLP Endpoints

```bash
# Test HTTP endpoint
curl http://localhost:4318/v1/traces

# Test gRPC endpoint (requires grpcurl)
grpcurl -plaintext localhost:4317 list
```

### Check Prometheus Targets

1. Open Prometheus UI: http://localhost:9090
2. Navigate to Status → Targets
3. Verify all targets are `UP`

### Verify Loki Ingestion

1. Open Grafana: http://localhost:3000
2. Go to Explore → Select Loki datasource
3. Run query: `{job="varlogs"}`

## 🛠️ Maintenance

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f otel-collector
docker compose logs -f prometheus
docker compose logs -f loki
docker compose logs -f grafana
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart otel-collector
```

### Update Configuration

After modifying configuration files:

```bash
# Restart affected service
docker compose restart otel-collector
docker compose restart prometheus
docker compose restart loki

# Or reload Prometheus config (if web.enable-lifecycle is enabled)
curl -X POST http://localhost:9090/-/reload
```

### Backup Data

```bash
# Backup Prometheus data
docker run --rm -v master_prometheus-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/prometheus-backup.tar.gz -C /data .

# Backup Loki data
tar czf loki-backup.tar.gz loki-data/
```

## 🔐 Security Considerations

1. **Change Default Passwords**: Update Grafana admin password on first login
2. **Firewall Rules**: Restrict access to services via firewall
3. **TLS/SSL**: Configure reverse proxy with SSL certificates for production
4. **Authentication**: Enable Grafana authentication providers (LDAP, OAuth, etc.)
5. **Network Isolation**: Use Docker networks to isolate services

## 📊 Monitoring & Alerting

### Pre-configured Alert Rules

Alert rules are provisioned in `grafana/provisioning/alerting/rules.yml`. Customize as needed.

### Grafana Dashboards

Import dashboards from the `Dashboards/` directory:

1. Grafana UI → Dashboards → Import
2. Upload JSON files from `Dashboards/` directory
3. Configure datasources as needed

### SNMP Monitoring

The stack includes SNMP exporter for network device monitoring. Configure targets in `prometheus.yml`:

```yaml
- job_name: 'cumulus-snmp-interfaces'
  metrics_path: /snmp
  params:
    module: [if_mib]
    auth: [cumulus_v3]
  static_configs:
    - targets:
        - SNMP_DEVICE_1_IP
        - SNMP_DEVICE_2_IP
```

## 🐛 Troubleshooting

### Containers Not Starting

```bash
# Check logs for errors
docker compose logs

# Verify disk space
df -h

# Check port conflicts
netstat -tulpn | grep -E '3000|3100|9090|4317|4318'
```

### Loki Disk Space Issues

Loki retention is set to 7 days. If disk space is a concern:

1. Reduce retention in `loki-config.yml`:
   ```yaml
   retention_period: 72h  # 3 days
   ```

2. Use the `loki-safety-trim.sh` script for emergency cleanup

### Prometheus High Memory Usage

Reduce retention or adjust scrape intervals:

```yaml
# In prometheus.yml
global:
  scrape_interval: 60s  # Increase from 30s
```

### OTLP Connection Issues

Verify network connectivity from agents:

```bash
# From agent server
telnet MASTER_SERVER_IP 4317
telnet MASTER_SERVER_IP 4318
```

## 📝 License

This project is provided as-is for operational use.

---

**Note:** Replace all placeholder values (YOUR_GRAFANA_DOMAIN_OR_IP, SNMP_DEVICE_X_IP, etc.) with your actual configuration values before deployment.

