# Enterprise Observability Stack - OpenTelemetry, Prometheus, Loki & Grafana

A complete, production-ready observability solution for centralized metrics, logs, and traces collection across distributed infrastructure. This stack provides automated deployment, intelligent resource management, and comprehensive monitoring capabilities.

## 🏗️ Architecture Overview

This project implements a **master-agent** observability architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    Master Server                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Prometheus  │  │     Loki     │  │   Grafana    │     │
│  │  (Metrics)   │  │    (Logs)    │  │(Visualization)│     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                  │                  │             │
│         └──────────────────┴──────────────────┘             │
│                            │                                 │
│                  ┌─────────▼─────────┐                       │
│                  │ OTel Collector    │                       │
│                  │    (Master)       │                       │
│                  └─────────┬─────────┘                       │
└────────────────────────────┼─────────────────────────────────┘
                              │
                              │ OTLP (gRPC/HTTP)
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
┌────────▼────────┐  ┌────────▼────────┐  ┌──────▼────────┐
│  Agent Server 1 │  │  Agent Server 2 │  │ Agent Server N│
│                 │  │                 │  │                │
│  OTel Agent    │  │  OTel Agent    │  │  OTel Agent   │
│  Promtail      │  │  Promtail      │  │  Promtail     │
│  (Metrics)     │  │  (Metrics)     │  │  (Metrics)    │
│  (Logs)        │  │  (Logs)        │  │  (Logs)       │
└─────────────────┘  └─────────────────┘  └───────────────┘
```

## 📦 Components

### Master Stack (`OpenTelemetry Collector/master/`)

Central observability hub providing:

- **OpenTelemetry Collector**: Receives and processes telemetry from agents
- **Prometheus**: Time-series database for metrics storage
- **Loki**: Log aggregation and storage system
- **Grafana**: Unified visualization and alerting platform
- **SNMP Exporter**: Network device monitoring

### Agent Deployment Options

#### Option 1: Ansible Deployment (`Ansible Agent OpenTelemetry Collector/`)

Automated agent deployment using Ansible:

- ✅ Automatic Docker detection
- ✅ Zero-touch deployment across multiple servers
- ✅ Intelligent configuration based on environment
- ✅ Real-time bash history collection
- ✅ Pre-configured Loki labels

**Best for**: Large-scale deployments, infrastructure automation

#### Option 2: Docker Compose Deployment (`OpenTelemetry Collector/slave/`)

Containerized agent deployment:

- ✅ Docker Compose-based setup
- ✅ Promtail for additional log collection
- ✅ Docker logging driver integration
- ✅ Environment-based configuration

**Best for**: Individual servers, containerized environments

### Maintenance Tools

#### Loki Safety Trim (`loki-safety/`)

Emergency disk space protection for Loki:

- Monitors Loki data directory size
- Automatic rotation when threshold exceeded
- Prevents disk space exhaustion
- Daily automated execution

#### Prometheus TSDB Trim (`prometheus-tsdb-trim.sh`)

Intelligent Prometheus block management:

- Removes old TSDB blocks by duration
- Automatic container detection
- Dry-run mode for testing
- Comprehensive logging

## 🚀 Quick Start

### 1. Deploy Master Stack

```bash
cd "OpenTelemetry Collector/master"

# Configure environment (update IPs, passwords in docker-compose.yml)
# Prepare Loki data directory
mkdir -p ./loki-data/wal
sudo chown -R 10001:10001 ./loki-data

# Start services
docker compose up -d
```

See [Master README](OpenTelemetry%20Collector/master/README.md) for detailed instructions.

### 2. Deploy Agents

#### Using Ansible (Recommended for multiple servers):

```bash
cd "Ansible Agent OpenTelemetry Collector"

# Edit inventory.ini with your servers
# Replace MASTER_SERVER_IP with your master server IP

# Deploy
ansible-playbook -i inventory.ini deploy_otel_agent.yml
```

See [Ansible Agent README](Ansible%20Agent%20OpenTelemetry%20Collector/README.md) for details.

#### Using Docker Compose (For individual servers):

```bash
cd "OpenTelemetry Collector/slave"

# Create .env file (replace MASTER_SERVER_IP)
# Configure environment variables

# Deploy
docker compose up -d
```

See [Slave README](OpenTelemetry%20Collector/slave/README.md) for details.

### 3. Set Up Maintenance Tools

#### Loki Safety Trim:

```bash
cd loki-safety
# Follow installation instructions in README.md
```

#### Prometheus TSDB Trim:

```bash
# Make script executable
chmod +x prometheus-tsdb-trim.sh

# Set up daily cron job
./setup-prometheus-trim-cron.sh
```

## 📊 Features

### Comprehensive Data Collection

- **Host Metrics**: CPU, memory, disk, network, processes
- **Container Metrics**: Docker container statistics
- **System Logs**: syslog, journald, application logs
- **Container Logs**: Docker container logs
- **Bash History**: Real-time command history for security auditing
- **SNMP Metrics**: Network device monitoring

### Intelligent Automation

- **Auto-Detection**: Docker installation detection
- **Smart Labeling**: Automatic resource labeling for better organization
- **Zero-Configuration**: Sensible defaults with easy customization
- **Health Monitoring**: Built-in health checks and status endpoints

### Production-Ready

- **High Availability**: Restart policies and health checks
- **Resource Management**: Automatic cleanup and retention policies
- **Security**: Secure defaults, authentication support
- **Scalability**: Designed for large-scale deployments

## 📁 Project Structure

```
.
├── README.md                                    # This file
├── Ansible Agent OpenTelemetry Collector/      # Ansible deployment
│   ├── deploy_otel_agent.yml                   # Main playbook
│   ├── inventory.ini                           # Server inventory
│   ├── template/                                # Configuration templates
│   └── README.md                               # Deployment guide
├── OpenTelemetry Collector/
│   ├── master/                                 # Master stack
│   │   ├── docker-compose.yml                  # Service definitions
│   │   ├── otelcol-config.yaml                 # Collector config
│   │   ├── prometheus.yml                      # Prometheus config
│   │   ├── loki-config.yml                     # Loki config
│   │   ├── grafana/                            # Grafana provisioning
│   │   └── README.md                           # Master setup guide
│   ├── slave/                                  # Agent deployment
│   │   ├── docker-compose.yml                  # Agent services
│   │   ├── otelcol-agent.yaml                  # Agent config
│   │   ├── promtail.yml                        # Promtail config
│   │   └── README.md                           # Agent setup guide
│   └── Dashboards/                            # Grafana dashboards
├── loki-safety/                                # Loki disk protection
│   ├── loki-safety-trim.sh                    # Safety script
│   └── README.md                              # Safety tool guide
├── prometheus-tsdb-trim.sh                     # Prometheus cleanup
├── setup-prometheus-trim-cron.sh               # Cron setup
└── README-prometheus-trim.md                  # Prometheus tool guide
```

## 🔧 Configuration

### Master Server

1. **Update IPs**: Replace `YOUR_GRAFANA_DOMAIN_OR_IP` in `docker-compose.yml`
2. **Configure SMTP**: Update email settings for Grafana alerts
3. **SNMP Targets**: Configure device IPs in `prometheus.yml`
4. **Retention**: Adjust retention periods in `loki-config.yml` and Prometheus

### Agent Servers

1. **Master Endpoints**: Set `MASTER_SERVER_IP` in inventory or `.env`
2. **Environment Labels**: Configure `pais`, `entorno`, `cliente` for labeling
3. **Service Names**: Automatically set to hostname (customizable)

## 📈 Data Flow

```
Agent Servers
    │
    ├─ Host Metrics ──────────────┐
    ├─ Container Metrics ─────────┤
    ├─ System Logs ────────────────┤
    ├─ Container Logs ─────────────┤
    └─ Bash History ────────────────┤
                                    │
                            OTLP (gRPC/HTTP)
                                    │
                            Master Collector
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
            Prometheus (Metrics)            Loki (Logs)
                    │                               │
                    └───────────────┬───────────────┘
                                    │
                              Grafana
                    (Unified Visualization)
```

## 🔍 Verification

### Master Stack

```bash
# Check all services
docker compose ps

# Verify endpoints
curl http://localhost:4318/v1/traces  # OTLP HTTP
curl http://localhost:9090/-/healthy  # Prometheus
curl http://localhost:3100/ready      # Loki
```

### Agent Deployment

```bash
# Check service status
systemctl status otelcol  # Ansible deployment
# or
docker compose ps         # Docker Compose deployment

# Verify metrics endpoint
curl http://localhost:8888/metrics
```

### Grafana Queries

**Metrics (Prometheus):**
```promql
up{service_name="YOUR_SERVICE_NAME"}
```

**Logs (Loki):**
```logql
{service="YOUR_SERVICE_NAME"}
```

## 🛠️ Maintenance

### Daily Operations

- **Loki Safety Trim**: Runs daily at 03:10 (automated)
- **Prometheus TSDB Trim**: Runs daily at 02:00 (automated)
- **Log Rotation**: Configured in Loki and Prometheus retention policies

### Monitoring

- **Disk Usage**: Monitor via Prometheus metrics or Grafana dashboards
- **Service Health**: Check container/service status regularly
- **Log Analysis**: Review agent and master logs for errors

### Backup

```bash
# Backup Prometheus data
docker run --rm -v master_prometheus-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/prometheus-backup.tar.gz -C /data .

# Backup Loki data
tar czf loki-backup.tar.gz loki-data/
```

## 🔐 Security Considerations

1. **Network Security**: Use VPN or private networks for agent-master communication
2. **Authentication**: Configure Grafana authentication (LDAP, OAuth, etc.)
3. **TLS/SSL**: Enable TLS for all external-facing services
4. **Firewall**: Restrict access to observability ports
5. **Credentials**: Store sensitive data in environment variables or secrets management

## 📚 Documentation

- [Ansible Agent Deployment Guide](Ansible%20Agent%20OpenTelemetry%20Collector/README.md)
- [Master Stack Setup Guide](OpenTelemetry%20Collector/master/README.md)
- [Agent/Slave Setup Guide](OpenTelemetry%20Collector/slave/README.md)
- [Loki Safety Trim Guide](loki-safety/README.md)
- [Prometheus TSDB Trim Guide](README-prometheus-trim.md)

## 🎯 Use Cases

- **Infrastructure Monitoring**: Server metrics, container metrics, network monitoring
- **Application Observability**: Application logs, traces, performance metrics
- **Security Auditing**: Bash history collection, command auditing
- **Network Monitoring**: SNMP-based network device monitoring
- **Multi-Environment**: Support for production, staging, development environments

## 🤝 Contributing

This is a production-ready observability stack. Feel free to:

- Submit issues for bugs or feature requests
- Fork and customize for your environment
- Share improvements and best practices

## 📝 License

This project is provided as-is for operational use.

## ⚠️ Important Notes

1. **Replace Placeholders**: All configuration files contain placeholders (e.g., `MASTER_SERVER_IP`, `YOUR_GRAFANA_DOMAIN_OR_IP`). Replace these with your actual values before deployment.

2. **Test First**: Always test in a non-production environment before deploying to production.

3. **Backup**: Implement regular backups of Prometheus and Loki data.

4. **Monitoring**: Monitor the monitoring stack itself - set up alerts for disk usage, service health, etc.

5. **Retention**: Configure appropriate retention policies based on your storage capacity and compliance requirements.

---

**Built for production. Designed for scale. Ready to deploy.**

