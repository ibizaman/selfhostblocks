# Services {#services}

| Service               | Backup | Reverse Proxy | SSO | LDAP  | Monitoring | Profiling |
|-----------------------|--------|---------------|-----|-------|------------|-----------|
| [Nextcloud Server][1] | P (1)  | Y             | N   | P (2) | Y          | P (3)     |

Legend: **N**: no but WIP; **P**: partial; **Y**: yes

1. Does not backup the database yet.
2. Works but requires manually setting up the integration.
3. Works but the traces are not exported to Grafana yet.

[1]: services-nextcloud.html

```{=include=} chapters html:into-file=//services-nextcloud.html
modules/services/nextcloud-server/docs/default.md
```
