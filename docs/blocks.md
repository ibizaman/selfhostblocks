<!-- Read these docs at https://shb.skarabox.com -->
# Blocks {#blocks}

Blocks help you self-host apps or services. They implement a specific function like backup or secure
access through a subdomain. Each block is designed to be usable on its own and to fit nicely with
others.

Not all blocks are documented yet.
You can find all available blocks [in the repository](@REPO@/modules/blocks).

## Authentication {#blocks-category-authentication}

```{=include=} chapters html:into-file=//blocks-authelia.html
modules/blocks/authelia/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-lldap.html
modules/blocks/lldap/docs/default.md
```

## Backup {#blocks-category-backup}

```{=include=} chapters html:into-file=//blocks-borgbackup.html
modules/blocks/borgbackup/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-restic.html
modules/blocks/restic/docs/default.md
```

## Database {#blocks-category-database}

```{=include=} chapters html:into-file=//blocks-postgresql.html
modules/blocks/postgresql/docs/default.md
```

## Secrets {#blocks-category-secrets}

```{=include=} chapters html:into-file=//blocks-sops.html
modules/blocks/sops/docs/default.md
```

## Network {#blocks-category-network}

```{=include=} chapters html:into-file=//blocks-ssl.html
modules/blocks/ssl/docs/default.md
```

## Introspection {#blocks-category-introspection}

```{=include=} chapters html:into-file=//blocks-monitoring.html
modules/blocks/monitoring/docs/default.md
```

```{=include=} chapters html:into-file=//blocks-mitmdump.html
modules/blocks/mitmdump/docs/default.md
```
