# Services {#services}

| Service               | Backup | Reverse Proxy | SSO | LDAP  | Monitoring | Profiling |
|-----------------------|--------|---------------|-----|-------|------------|-----------|
| [Nextcloud Server][1] | P (1)  | Y             | N   | Y     | Y          | P (2)     |

Legend: **N**: no but WIP; **P**: partial; **Y**: yes

1. Does not backup the database yet.
2. Works but the traces are not exported to Grafana yet.

[1]: services-nextcloud.html

```{=include=} chapters html:into-file=//services-nextcloud.html
modules/services/nextcloud-server/docs/default.md
```
