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
| [*Arr][]             | Y (1)  | Y             | Y   | Y (4) | Y (2)      | N         |
| [Forgejo][]          | Y (1)  | Y             | Y   | Y     | Y (2)      | N         |
| [Home-Assistant][]   | Y (1)  | Y             | N   | Y     | Y (2)      | N         |
| [Nextcloud Server][] | Y (1)  | Y             | Y   | Y     | Y (2)      | P (3)     |
| [Vaultwarden][]      | Y (1)  | Y             | Y   | Y     | Y (2)      | N         |

Legend: **N**: no but WIP; **P**: partial; **Y**: yes

1. Database and data files are backed up separately.
   This could lead to backups not being in sync.
   Any idea on how to fix this is welcomed!
2. Dashboard is common to all services.
3. Works but the traces are not exported to Grafana yet.
4. Uses LDAP indirectly through forward auth.

[*Arr]: services-arr.html
[Forgejo]: services-forgejo.html
[Home-Assistant]: services-home-assistant.html
[Nextcloud Server]: services-nextcloud.html
[Vaultwarden]: services-vaultwarden.html

```{=include=} chapters html:into-file=//services-arr.html
modules/services/arr/docs/default.md
```

```{=include=} chapters html:into-file=//services-forgejo.html
modules/services/forgejo/docs/default.md
```

```{=include=} chapters html:into-file=//services-home-assistant.html
modules/services/home-assistant/docs/default.md
```

```{=include=} chapters html:into-file=//services-nextcloud.html
modules/services/nextcloud-server/docs/default.md
```

```{=include=} chapters html:into-file=//services-vaultwarden.html
modules/services/vaultwarden/docs/default.md
```
