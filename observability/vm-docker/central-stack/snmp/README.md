# SNMP exporter (optional)

1. Build `snmp.yml` with the [snmp_exporter generator](https://github.com/prometheus/snmp_exporter/tree/main/generator) for your devices (e.g. Cumulus, generic IF-MIB).
2. Place the generated file as `snmp/snmp.yml`.
3. Start the profile: `docker compose --profile snmp up -d`.
4. Add scrape jobs to `prometheus.yml` (see `prometheus-scrape-snmp.example.yml`).
