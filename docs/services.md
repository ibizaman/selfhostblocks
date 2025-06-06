<!-- Read these docs at https://shb.skarabox.com -->
# Services {#services}

Services are usually web applications that SHB help you self-host. Configuration of those is
purposely made opinionated and require as few nix options as can make sense. That is possible thanks to the extensive use of blocks provided by SHB.

::: {.note}
Not all services are yet documented. You can find all available services [in the repository](@REPO@/modules/services).
:::

The following table summarizes for each documented service what features it provides. More
information is provided in the respective manual sections.

| Service               | Backup | Reverse Proxy | SSO | LDAP  | Monitoring | Profiling |
|-----------------------|--------|---------------|-----|-------|------------|-----------|
| [Nextcloud Server][1] | Y (1)  | Y             | Y   | Y     | Y (2)      | P (3)     |
| [Vaultwarden][2]      | Y (1)  | Y             | Y   | Y     | Y (2)      | N         |
| [Forgejo][3]          | Y (1)  | Y             | Y   | Y     | Y (2)      | N         |

Legend: **N**: no but WIP; **P**: partial; **Y**: yes

1. Database and data files are backed up separately.
2. Dashboard is common to all services.
3. Works but the traces are not exported to Grafana yet.

[1]: services-nextcloud.html
[2]: services-vaultwarden.html
[3]: services-forgejo.html

```{=include=} chapters html:into-file=//services-nextcloud.html
modules/services/nextcloud-server/docs/default.md
```

```{=include=} chapters html:into-file=//services-vaultwarden.html
modules/services/vaultwarden/docs/default.md
```

```{=include=} chapters html:into-file=//services-forgejo.html
modules/services/forgejo/docs/default.md
```
