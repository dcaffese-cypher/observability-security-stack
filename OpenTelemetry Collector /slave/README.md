# OpenTelemetry Collector Agent / Slave Deployment

Deployment guide for OpenTelemetry Collector agents (slaves) that collect metrics and logs from individual servers and forward them to the master observability stack.

## 🎯 Overview

This agent deployment uses:
- **OpenTelemetry Collector**: Collects host and container metrics, system logs, and Docker container logs
- **Promtail**: Collects additional log files (system logs, bash history) and forwards to Loki
- **Docker Logging Driver**: Direct Docker log forwarding to Loki

All telemetry is forwarded to the master collector for centralized processing.

## 📋 Prerequisites

- Docker ≥ 20.10
- Docker Compose plugin ≥ 2.0
- Access to master collector endpoints
- Root or sudo access for log file access

## 🚀 Quick Start

### 1. Prepare Environment File

Create a `.env` file with your configuration:

```bash
cat > .env <<'EOF'
# Environment metadata
PAIS=AT
ENTORNO=PRD
CLIENTE=your-client

# Service name (automatically set to hostname)
SERVICE_NAME=$(hostname -s)

# Master OpenTelemetry Collector endpoints
# Replace MASTER_SERVER_IP with your master server IP or hostname
MASTER_OTLP_HTTP=http://MASTER_SERVER_IP:4318
MASTER_OTLP_GRPC=MASTER_SERVER_IP:4317

# Master Loki endpoint
LOKI_URL=http://MASTER_SERVER_IP:3100

# Docker socket GID (will be auto-filled)
DOCKER_SOCK_GID=
EOF
```

### 2. Auto-Configure Dynamic Variables

Run these commands to automatically fill dynamic values:

```bash
# Fill Docker socket GID
sed -i "s|DOCKER_SOCK_GID=|DOCKER_SOCK_GID=$(stat -c '%g' /var/run/docker.sock)|" .env

# Force the real server name (in case .env is cloned)
SN=$(hostname -s)
sed -i "s|^SERVICE_NAME=.*|SERVICE_NAME=${SN}|" .env || echo "SERVICE_NAME=${SN}" >> .env

# Verify configuration
grep ^SERVICE_NAME .env
```

### 3. Prepare Directories

Create required directories:

```bash
mkdir -p /var/lib/promtail
```

### 4. Install Loki Docker Logging Driver

Install the Loki Docker logging driver plugin (only needed once per host):

```bash
sudo docker plugin install grafana/loki-docker-driver:latest \
  --alias loki \
  --grant-all-permissions
```

### 5. Deploy Agent Services

Start the agent services:

```bash
docker compose up -d
```

### 6. Verify Deployment

Check that containers are running:

```bash
docker compose ps
```

You should see:
- `otel_collector` - OpenTelemetry Collector agent
- `agent_promtail` - Promtail log collector

## 📊 What Gets Collected

### OpenTelemetry Collector

The agent collects:

- **Host Metrics**: CPU, memory, disk, filesystem, network, load, paging, processes
- **Docker Metrics**: Container CPU, memory, network, I/O statistics
- **Docker Logs**: All container logs from `/var/lib/docker/containers/*/*.log`
- **System Logs**: Logs from `/var/log/containers/*.log`

### Promtail

Promtail collects:

- **System Logs**: All files in `/var/log/*.log`
- **Bash History**: User and root bash history files for security auditing
  - `/home/*/.bash_history`
  - `/root/.bash_history`

### Docker Logging Driver

All Docker container logs are automatically forwarded to Loki via the logging driver with labels:
- `pais`, `entorno`, `cliente`, `service` (from `.env`)

## 🔍 Verification

### Check Metrics in Prometheus

In Grafana or Prometheus, query for your service:

```promql
up{service_name="YOUR_SERVICE_NAME"}
```

### Check Logs in Loki

In Grafana, query Loki for your service:

```logql
{service="YOUR_SERVICE_NAME"}
```

or by hostname:

```logql
{hostname="YOUR_SERVICE_NAME"}
```

### Verify Container Logs

Check that container logs are being collected:

```bash
# View OpenTelemetry Collector logs
docker logs otel_collector

# View Promtail logs
docker logs agent_promtail

# Check for errors
docker logs otel_collector 2>&1 | grep -i error
docker logs agent_promtail 2>&1 | grep -i error
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PAIS` | Country code | `AT`, `US`, `DE` |
| `ENTORNO` | Environment | `PRD`, `DEV`, `STG` |
| `CLIENTE` | Client identifier | `your-client`, `client1` |
| `SERVICE_NAME` | Service/hostname identifier | Auto-set to `$(hostname -s)` |
| `MASTER_OTLP_HTTP` | Master OTLP HTTP endpoint | `http://192.168.1.100:4318` |
| `MASTER_OTLP_GRPC` | Master OTLP gRPC endpoint | `192.168.1.100:4317` |
| `LOKI_URL` | Master Loki endpoint | `http://192.168.1.100:3100` |
| `DOCKER_SOCK_GID` | Docker socket group ID | Auto-detected |

### OpenTelemetry Collector Configuration

The collector configuration is in `otelcol-agent.yaml`. Key features:

- **Host Metrics**: Collected from `/hostfs` mount (host filesystem)
- **Docker Stats**: Collected via Docker socket
- **Service Name**: Set from `SERVICE_NAME` environment variable
- **Exporters**: OTLP HTTP to master collector

### Promtail Configuration

Promtail configuration is in `promtail.yml`. It collects:

- System logs from `/var/log/*.log`
- Bash history from user home directories
- All logs are labeled with `pais`, `entorno`, `cliente`, `hostname`

## 🛠️ Maintenance

### View Logs

```bash
# OpenTelemetry Collector
docker logs -f otel_collector

# Promtail
docker logs -f agent_promtail
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart otel-collector
docker compose restart promtail
```

### Update Configuration

After modifying configuration files:

```bash
# Restart affected service
docker compose restart otel-collector
docker compose restart promtail
```

### Enable Real-Time History

Run the history script to enable real-time bash history collection:

```bash
./enable_realtime_history.sh
```

This configures bash to write history immediately, enabling real-time collection by Promtail.

## 🐛 Troubleshooting

### Containers Not Starting

```bash
# Check logs
docker compose logs

# Verify .env file exists and is configured
cat .env

# Check Docker socket permissions
ls -l /var/run/docker.sock
```

### No Metrics in Prometheus

1. Verify connectivity to master:
   ```bash
   telnet MASTER_SERVER_IP 4318
   ```

2. Check OpenTelemetry Collector logs:
   ```bash
   docker logs otel_collector | grep -i error
   ```

3. Verify service name:
   ```bash
   docker exec otel_collector env | grep SERVICE_NAME
   ```

### No Logs in Loki

1. Check Promtail logs:
   ```bash
   docker logs agent_promtail
   ```

2. Verify Loki connectivity:
   ```bash
   curl -v http://MASTER_SERVER_IP:3100/ready
   ```

3. Check file permissions:
   ```bash
   ls -la /var/log/
   ls -la /home/
   ```

### Docker Socket Permission Issues

If the collector cannot access Docker socket:

```bash
# Check current GID
stat -c '%g' /var/run/docker.sock

# Update .env with correct GID
sed -i "s|DOCKER_SOCK_GID=.*|DOCKER_SOCK_GID=$(stat -c '%g' /var/run/docker.sock)|" .env

# Restart services
docker compose restart
```

### High Resource Usage

If the agent uses too many resources:

1. Increase collection intervals in `otelcol-agent.yaml`:
   ```yaml
   collection_interval: 30s  # Increase from 15s
   ```

2. Reduce log file collection scope in `promtail.yml`

## 📈 Data Flow

```
Host Metrics → OpenTelemetry Collector → Master Collector → Prometheus
Docker Metrics → OpenTelemetry Collector → Master Collector → Prometheus
Docker Logs → OpenTelemetry Collector → Master Collector → Loki
System Logs → Promtail → Loki (Master)
Bash History → Promtail → Loki (Master)
```

## 🔐 Security Considerations

1. **File Access**: Agent needs read access to `/var/log`, `/home`, `/root` for log collection
2. **Docker Socket**: Agent needs Docker socket access for container metrics/logs
3. **Network**: Ensure secure network connection to master (consider VPN or private network)
4. **Credentials**: Store sensitive configuration in `.env` file with appropriate permissions

## 📝 License

This project is provided as-is for operational use.

---

**Note:** Replace `MASTER_SERVER_IP` and `YOUR_SERVICE_NAME` with your actual values before deployment.

