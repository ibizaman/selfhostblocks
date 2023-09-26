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
  - [ ] UI for backups.
  - [ ] Export metrics to Prometheus.
- [X] Monitoring through Prometheus and Grafana.
  - [X] Export systemd services status.
- [X] Reverse Proxy with Nginx.
  - [ ] Export metrics to Prometheus.
  - [ ] Log slow requests.
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
  - [X] SSO auth.
  - [X] Backup support.
- [X] Hledger
  - [ ] Export metrics to Prometheus.
  - [X] LDAP auth through `hledger_user` LDAP group.
  - [X] SSO auth.
  - [ ] Backup support.
- [X] Database Postgres
  - [ ] Slow log monitoring.
  - [ ] Export metrics to Prometheus.

## Tips

### Deploy

```bash
$ nix run nixpkgs#colmena -- apply
```

### Diff changes

```bash
$ nix run nixpkgs#colmena -- build
...
Built "/nix/store/yyw9rgn8v5jrn4657vwpg01ydq0hazgx-nixos-system-baryum-23.11pre-git"

# Make some changes

$ nix run nixpkgs#colmena -- build
...
Built "/nix/store/16n1klx5cxkjpqhrdf0k12npx3vn5042-nixos-system-baryum-23.11pre-git"

$ nix run nixpkgs#nix-diff -- \
  /nix/store/yyw9rgn8v5jrn4657vwpg01ydq0hazgx-nixos-system-baryum-23.11pre-git \
  /nix/store/16n1klx5cxkjpqhrdf0k12npx3vn5042-nixos-system-baryum-23.11pre-git \
  --color always | less
```
