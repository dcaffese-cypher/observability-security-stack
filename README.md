# Enterprise Observability & Security Stack

### OpenTelemetry · Prometheus · Loki · Grafana · Wazuh · Zabbix

A **production-ready observability and security stack** for centralized **metrics, logs, traces and security signals** across distributed infrastructure.

This repository consolidates **real-world operational tooling** used in production environments, providing automated deployment, intelligent resource management and maintenance utilities.

---

## 🚀 Quick Start

```bash
git clone https://github.com/dcaffese-cypher/observability-security-stack.git
cd observability-security-stack
```

Each folder is an **independent module**.
Start with the **master stack**, then deploy agents using Ansible or Docker.

---

## 🏗️ Architecture Overview

This project implements a **master–agent observability architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│                        Master Server                         │
│                                                             │
│   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
│   │ Prometheus   │   │     Loki     │   │   Grafana    │  │
│   │ (Metrics)    │   │   (Logs)     │   │ Visualization│  │
│   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘  │
│          │                  │                  │          │
│          └──────────────┬──────────────────────┘          │
│                         │                                 │
│                ┌────────▼────────┐                        │
│                │ OpenTelemetry   │                        │
│                │ Collector       │                        │
│                │ (Master)        │                        │
│                └────────┬────────┘                        │
└─────────────────────────┼─────────────────────────────────┘
                          │  OTLP (gRPC / HTTP)
        ┌─────────────────┼─────────────────────────────────┐
        │                 │                 │                 │
┌───────▼────────┐ ┌──────▼────────┐ ┌──────▼────────┐
│ Agent Server 1  │ │ Agent Server 2 │ │ Agent Server N │
│ OTel Agent      │ │ OTel Agent     │ │ OTel Agent     │
│ Metrics & Logs  │ │ Metrics & Logs │ │ Metrics & Logs │
└─────────────────┘ └────────────────┘ └─────────────────┘
```

---

## 📦 Components

### Master Stack

**`opentelemetry-collector/master/`**

Central observability hub providing:

* **OpenTelemetry Collector** – central telemetry ingestion
* **Prometheus** – metrics storage and querying
* **Loki** – log aggregation and retention
* **Grafana** – dashboards, alerting and visualization
* **SNMP Exporter** – network device monitoring

---

### Agent Deployment Options

#### Option 1: Ansible (Recommended)

**`ansible-agent-otel-collector/`**

Automated agent deployment using Ansible:

* Automatic Docker detection
* Zero-touch multi-host deployment
* Intelligent environment-based configuration
* Real-time bash history collection
* Preconfigured Loki labels

**Best for:** large-scale and enterprise environments

---

#### Option 2: Docker Compose

**`opentelemetry-collector/slave/`**

Containerized agent deployment:

* Docker Compose based
* Docker logging driver integration
* `.env`-based configuration

**Best for:** individual servers and container-focused setups

---

## 🧰 Maintenance & Safety Tools

### Loki Safety Trim

**`loki-safety/`**

Disk-space protection for Loki:

* Monitors Loki data directory size
* Automatic trimming on threshold breach
* Prevents disk exhaustion
* Cron-based daily execution

---

### Prometheus TSDB Trim

**`prometheus-tsdb-trim.sh`**

Intelligent Prometheus block cleanup:

* Removes old TSDB blocks by retention period
* Automatic container detection
* Dry-run mode
* Structured logging

---

## 🚀 Deployment Guide

### 1️⃣ Deploy Master Stack

```bash
cd opentelemetry-collector/master

mkdir -p ./loki-data/wal
sudo chown -R 10001:10001 ./loki-data

docker compose up -d
```

See **`opentelemetry-collector/master/README.md`** for details.

---

### 2️⃣ Deploy Agents

**Ansible (recommended):**

```bash
cd ansible-agent-otel-collector
ansible-playbook -i inventory.ini deploy_otel_agent.yml
```

**Docker Compose:**

```bash
cd opentelemetry-collector/slave
docker compose up -d
```

---

### 3️⃣ Enable Maintenance Jobs

```bash
chmod +x prometheus-tsdb-trim.sh
./setup-prometheus-trim-cron.sh
```

---

## 📊 Features

### Observability

* Host metrics (CPU, memory, disk, network)
* Container metrics
* System and application logs
* Docker container logs
* Traces (OTLP)
* SNMP network metrics

### Security & Auditing

* Real-time bash history collection
* Wazuh dashboards and API fixes
* Command auditing support

### Automation

* Auto-detection of runtime environment
* Smart labeling (environment, client, country)
* Health checks and restart policies

---

## 📁 Project Structure

```
.
├── ansible-agent-otel-collector/
├── opentelemetry-collector/
│   ├── master/
│   ├── slave/
│   └── Dashboards/
├── loki-safety/
├── zabbix/
├── Wazuh/
├── prometheus-tsdb-trim.sh
├── setup-prometheus-trim-cron.sh
├── README-prometheus-trim.md
└── README.md
```

---

## 🔍 Verification

**Master:**

```bash
docker compose ps
curl http://localhost:9090/-/healthy
curl http://localhost:3100/ready
```

**Agent:**

```bash
systemctl status otelcol
# or
docker compose ps
```

---

## 🔐 Security Considerations

* Use private networks or VPNs for OTLP traffic
* Restrict access to observability ports
* Enable TLS where applicable
* Store secrets in environment variables or vaults
* Apply proper retention policies

---

## 🎯 Use Cases

* Infrastructure monitoring
* Application observability
* Security auditing
* Network monitoring (SNMP)
* Multi-environment deployments (prod/stage/dev)

---

## 🤝 Contributing

This repository reflects **real production usage**.

You’re welcome to:

* Open issues
* Fork and adapt
* Share improvements

---

## ⚠️ Important Notes

* Replace all placeholders (`MASTER_SERVER_IP`, domains, credentials)
* Test in non-production first
* Back up Prometheus and Loki data
* Monitor the observability stack itself

---

**Built for production. Designed for scale. Ready to deploy.**

* Ajustarlo aún más para **audiencia LinkedIn**
* Agregar un **diagrama visual**
* O hacer una **versión resumida** para el post

Decime cómo seguimos.
