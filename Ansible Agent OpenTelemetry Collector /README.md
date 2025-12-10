# OpenTelemetry Collector Agent - Automated Ansible Deployment

A production-ready Ansible playbook for deploying OpenTelemetry Collector agents across multiple servers with intelligent Docker detection, automatic log collection, and centralized observability.

## 🚀 Features

- **🔍 Intelligent Docker Detection**: Automatically detects Docker installation and configures container metrics and log collection
- **📊 Comprehensive Metrics Collection**: Host metrics (CPU, memory, disk, network) and optional Docker container metrics
- **📝 Multi-Source Log Collection**: System logs, journald, and Docker container logs
- **🏷️ Automatic Labeling**: Pre-configured Loki labels for better log organization (host, client, environment, country)
- **⚡ Real-Time History**: Automatic bash history collection for security auditing
- **🔧 Flexible Configuration**: Supports both Docker and non-Docker environments
- **📦 Zero-Touch Deployment**: Single command deployment across multiple servers

## 📋 Prerequisites

- Ansible ≥ 2.9
- SSH access to target servers with sudo/root privileges
- Target servers running Linux (tested on RHEL/CentOS/Rocky Linux, Ubuntu, Debian)
- Master OpenTelemetry Collector server accessible from agents

## 📁 Project Structure

```
.
├── deploy_otel_agent.yml          # Main Ansible playbook
├── template/
│   └── otelcol-agent.yml.j2      # Jinja2 template with Docker detection
├── enable_realtime_history.sh    # Real-time history configuration script
├── inventory.ini                  # Server inventory configuration
└── README.md                      # This file
```

## 🛠️ Quick Start

### 1. Configure Inventory

Edit `inventory.ini` with your server details:

```ini
[agents]
# Replace with your actual server IPs or hostnames
agent-server-1 ansible_user=root pais=AT entorno=PRD cliente=your-client
agent-server-2 ansible_user=root pais=AT entorno=PRD cliente=your-client compose_project=myapp

[agents:vars]
# Master OpenTelemetry Collector endpoints
# Replace MASTER_SERVER_IP with your master collector server IP or hostname
master_otlp_http=http://MASTER_SERVER_IP:4318
master_otlp_grpc=MASTER_SERVER_IP:4317

# OpenTelemetry Collector version
otelcol_version=0.131.0

# Enable traces pipeline (optional)
enable_traces=false
```

### 2. Deploy Agents

Run the Ansible playbook:

```bash
ansible-playbook -i inventory.ini deploy_otel_agent.yml -vvv
```

The `-vvv` flag provides verbose output to monitor the installation process in real-time.

### 3. Verify Deployment

On each target server, verify the service is running:

```bash
# Check service status
systemctl status otelcol

# Verify internal telemetry endpoint
curl http://localhost:8888/metrics

# View service logs
journalctl -u otelcol -f
```

## 📚 Configuration Guide

### Required Variables

These variables must be defined in `inventory.ini`:

| Variable | Description | Example |
|----------|-------------|---------|
| `master_otlp_http` | HTTP endpoint of master collector | `http://192.168.1.100:4318` |
| `master_otlp_grpc` | gRPC endpoint of master collector | `192.168.1.100:4317` |
| `otelcol_version` | OpenTelemetry Collector version | `0.131.0` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_traces` | `false` | Enable traces pipeline |
| `compose_project` | - | Docker Compose project name |
| `compose_service` | - | Docker Compose service name |
| `container_name` | - | Specific container name to monitor |
| `filename` | - | Log file name pattern |
| `service_name` | - | Custom service name |
| `source` | - | Log source identifier |

### Per-Host Variables

Configure these for each server in the inventory:

| Variable | Description | Example |
|----------|-------------|---------|
| `pais` | Country code | `AT`, `US`, `DE` |
| `entorno` | Environment | `PRD`, `DEV`, `STG` |
| `cliente` | Client identifier | `your-client`, `client1` |
| `ansible_user` | SSH user | `root`, `admin` |

## 🔄 Behavior by Environment

### Servers Without Docker

When Docker is not detected, the agent collects:

- **Metrics**: Host system metrics (CPU, memory, disk, network, load, processes)
- **Logs**: System logs from `/var/log/syslog`, `/var/log/messages`, and journald
- **Configuration**: Uses `root_path: /` for hostmetrics collection

### Servers With Docker

When Docker is detected, the agent automatically:

- **Metrics**: Collects both host and container metrics via `docker_stats` receiver
- **Logs**: Collects Docker container logs from `/var/lib/docker/containers/*/*-json.log`
- **Dependencies**: Configures systemd service dependencies on Docker
- **Permissions**: Adds collector service to Docker group for socket access

## 🏷️ Automatic Labeling

The playbook automatically configures resource attributes for optimal log organization in Loki:

| Label | Source | Description |
|-------|--------|-------------|
| `host` | Server hostname | Identifies the source server |
| `source` | Always `"otelcol"` | Identifies the collection source |
| `cliente` | Inventory variable | Client identifier |
| `entorno` | Inventory variable | Environment (PRD, DEV, etc.) |
| `pais` | Inventory variable | Country code |

**Service Naming Convention:**

- `service.name` is automatically set to the server's hostname
- All logs and metrics (host and containers) appear under the same `service.name`
- Containers are automatically identified via Docker metadata (container_name, container_image, etc.)

**Example:**

```ini
agent-server-1 ansible_user=root pais=AT entorno=PRD cliente=your-client
```

This configuration results in:
- `service.name="agent-server-1"`
- Labels: `cliente="your-client"`, `entorno="PRD"`, `pais="AT"`

## 🔐 Real-Time History Collection

The playbook automatically installs and configures `enable_realtime_history.sh`, which:

- Enables `histappend` in `.bashrc` for all users
- Configures `PROMPT_COMMAND` to write history immediately
- Applies configuration to both regular users and root
- Enables bash history collection for security auditing in Loki

## 🐛 Troubleshooting

### Verify Docker Detection

Test the playbook in check mode to see Docker detection:

```bash
ansible-playbook -i inventory.ini deploy_otel_agent.yml --check -v
```

### Inspect Generated Configuration

View the generated configuration file on a target server:

```bash
cat /etc/otelcol/otelcol-agent.yml
```

### View Service Logs

Monitor the collector service logs:

```bash
journalctl -u otelcol -f
```

### Common Issues

#### Docker Log Timestamp Parsing Errors

**Error:**
```
failed to emit token ... time parser: parsing time "2025-10-01T18:00:41.51516361Z" 
as "2006-01-02T15:04:05.000000000Z07:00": cannot parse ".51516361Z" as ".000000000"
```

**Solution:** This is already fixed in the template. The configuration uses `strptime` with `%f`, which accepts 1-9 fractional digits.

#### "Broken Pipe" Errors in Prometheus

**Error:**
```
error encoding and sending metric family: write tcp 127.0.0.1:9464->127.0.0.1:57778: 
write: broken pipe
```

**Solution:** This is expected behavior. The template sends all metrics via OTLP to the master collector. The Prometheus exporter on port 9464 is intentionally not configured.

#### Docker Socket Permission Issues

If the collector cannot access the Docker socket:

```bash
# Add root to docker group (if not already)
sudo groupadd --system docker
sudo usermod -aG docker root

# Reload systemd and restart service
sudo systemctl daemon-reload
sudo systemctl restart otelcol.service
```

## 📊 Advanced: IBM Spectrum Scale (GPFS) Log Collection

To collect IBM Spectrum Scale (GPFS) logs, add the following receiver configuration to the template:

```yaml
receivers:
  filelog/gpfs:
    include: [ /var/adm/ras/mmfs.log.latest ]
    start_at: beginning
    include_file_path: true
    operators:
      - type: move
        from: attributes["log.file.path"]
        to: resource["log.file.path"]
      - type: add
        field: resource["log.type"]
        value: "gpfs"
      - type: add
        field: resource["component"]
        value: "mmfs"
```

Then update the logs pipeline:

```yaml
logs:
  receivers: [filelog/sys, filelog/gpfs, journald, otlp]
  processors: [resourcedetection, resource/service, resource/labels, resource/loki_labels, batch]
  exporters: [otlphttp]
```

Query GPFS logs in Grafana:

```logql
{log.file.path="/var/adm/ras/mmfs.log.latest"}
```

or

```logql
{log.type="gpfs", host="YOUR_SERVER_HOSTNAME"}
```

## 📝 License

This project is provided as-is for operational use.

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

---

**Note:** Replace all placeholder values (MASTER_SERVER_IP, YOUR_SERVER_HOSTNAME, etc.) with your actual configuration values before deployment.

