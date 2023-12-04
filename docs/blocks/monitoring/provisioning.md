# Provisioning {#blocks-monitoring-provisioning}

Self Host Blocks will create automatically the following resources:

- For Grafana:
  - datasources
  - dashboards
  - contact points
  - notification policies
  - alerts
- For Prometheus, the following exporters and related scrapers:
  - node
  - smartctl
  - nginx
- For Loki, the following exporters and related scrapers:
  - systemd

Those resources are namespaced as appropriate under the Self Host Blocks namespace:

[](./assets/folder.png)
