<!-- Read these docs at https://shb.skarabox.com -->
# Blocks {#blocks}

Blocks help you self-host apps or services. They implement a specific function like backup or secure
access through a subdomain. Each block is designed to be usable on its own and to fit nicely with
others.

All blocks are implemented under the blocks folder [in the repository](@REPO@/modules/blocks).

All services in SHB document how to setup the various blocks provided here.
For custom services or those not provided by SHB,
the [Expose a service Recipe](recipes-exposeService.html) explains how to use the blocks here.

**Authentication** []{#blocks-category-authentication}

- [Authelia][]
- [LLDAP][]

**Backup** []{#blocks-category-backup}

- [BorgBackup][]
- [Restic][]
- [Sanoid][]

**Database** []{#blocks-category-database}

- [PostgreSQL][]

**Secrets** []{#blocks-category-secrets}

- [SOPS][]

**Filesystem** []{#blocks-category-filesystem}

- [ZFS][]

**Network** []{#blocks-category-network}

- [SSL][]
- [nginx][]

**Introspection** []{#blocks-category-introspection}

- [Monitoring][] (Grafana, Prometheus, Fluent-Bit)
- [mitmdump][]


[Authelia]: blocks-authelia.html
[BorgBackup]: blocks-borgbackup.html
[LLDAP]: blocks-lldap.html
[mitmdump]: blocks-mitmdump.html
[monitoring]: blocks-monitoring.html
[nginx]: blocks-nginx.html
[postgresql]: blocks-postgresql.html
[sops]: blocks-sops.html
[ssl]: blocks-ssl.html
[restic]: blocks-restic.html
[sanoid]: blocks-sanoid.html
[zfs]: blocks-zfs.html

```{=include=} chapters html:into-file=//blocks-authelia.html
modules/blocks/authelia/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-borgbackup.html
modules/blocks/borgbackup/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-lldap.html
modules/blocks/lldap/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-mitmdump.html
modules/blocks/mitmdump/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-monitoring.html
modules/blocks/monitoring/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-nginx.html
modules/blocks/nginx/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-postgresql.html
modules/blocks/postgresql/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-sops.html
modules/blocks/sops/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-ssl.html
modules/blocks/ssl/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-restic.html
modules/blocks/restic/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-sanoid.html
modules/blocks/sanoid/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-zfs.html
modules/blocks/zfs/docs/default.md
```
