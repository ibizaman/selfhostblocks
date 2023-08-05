# Self Host Blocks

<!--toc:start-->
- [Self Host Blocks](#self-host-blocks)
  - [Supported Features](#supported-features)
<!--toc:end-->

*Building blocks for self-hosting with battery included.*

SHB's (Self Host Blocks) goal is to provide a lower entry-bar for self-hosting. I intend to achieve
this by providing opinionated building blocks fitting together to self-host a wide range of
services. Also, the design will be extendable to allow users to add services not provided by SHB.

## Supported Features

- [X] Authelia as SSO provider.
  - [X] Export metrics to Prometheus.
- [X] LDAP server through lldap, it provides a nice Web UI.
  - [X] Administrative UI only accessible from local network.
- [X] Backup with Restic or BorgBackup
- [X] Monitoring through Prometheus and Grafana.
  - [X] Export systemd services status.
- [X] Reverse Proxy with Nginx.
  - [ ] Export metrics to Prometheus.
  - [X] SSL support.
  - [X] Backup support.
- [X] Nextcloud
  - [ ] Export metrics to Prometheus.
  - [X] LDAP auth, unfortunately we need to configure this manually.
  - [ ] SSO auth.
  - [X] Backup support.
- [X] Home Assistant.
  - [ ] Export metrics to Prometheus.
  - [X] LDAP auth through `homeassistant_user` LDAP group.
  - [ ] SSO auth.
  - [X] Backup support.
- [X] Jellyfin
  - [ ] Export metrics to Prometheus.
  - [X] LDAP auth through `jellyfin_user` and `jellyfin_admin` LDAP groups.
  - [ ] SSO auth.
  - [X] Backup support.
