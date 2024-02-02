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
| [Nextcloud Server][1] | P (1)  | Y             | Y   | Y     | Y          | P (2)     |

Legend: **N**: no but WIP; **P**: partial; **Y**: yes

1. Does not backup the database yet.
2. Works but the traces are not exported to Grafana yet.

[1]: services-nextcloud.html

```{=include=} chapters html:into-file=//services-nextcloud.html
modules/services/nextcloud-server/docs/default.md
```
