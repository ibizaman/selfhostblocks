# Monitoring Block {#blocks-monitoring}

Defined in [`/modules/blocks/monitoring.nix`](@REPO@/modules/blocks/monitoring.nix).

This block sets up the monitoring stack for Self Host Blocks. It is composed of:

- Grafana as the dashboard frontend.
- Prometheus as the database for metrics.
- Loki as the database for logs.

```{=include=} parts
configuration.md
provisioning.md
dashboard-errors.md
dashboard-performance.md
alerts-requests-error-budger.md
```
