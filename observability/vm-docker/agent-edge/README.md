# OTel agent stack (VM / edge host)

Docker Compose stack: **OpenTelemetry Collector** agent plus optional **Promtail** for file logs. Forwards metrics and logs to the **central** collector or Loki.

## Setup

```bash
cp .env.example .env
# Edit .env: set MASTER_OTLP_HTTP, MASTER_OTLP_GRPC, LOKI_URL, CLIENTE, etc.
docker compose up -d
```

See [PLACEHOLDERS.md](../../PLACEHOLDERS.md) for naming conventions.

## Prerequisites

- Docker Engine and Compose plugin
- Network path to central OTLP and Loki endpoints

Full pipeline and architecture: [ARCHITECTURE.md](../../ARCHITECTURE.md).
