<!-- Read these docs at https://shb.skarabox.com -->
# Services {#services}

Services are usually web applications that SHB help you self-host some of your data.
Configuration of those is purposely made more opinionated than the upstream nixpkgs modules
in exchange for an uniformized configuration experience.
That is possible thanks to the extensive use of blocks provided by SHB.

::: {.note}
Not all services are yet documented. You can find all available services [in the repository](@REPO@/modules/services).
:::

The following table summarizes for each documented service what features it provides. More
information is provided in the respective manual sections.

| Service                     | Backup | Reverse Proxy | SSO | LDAP  | Monitoring | Profiling |
|-----------------------------|--------|---------------|-----|-------|------------|-----------|
| [*Arr][]                    | Y (1)  | Y             | Y   | Y (4) | Y (2)      | N         |
| [Firefly-iii][]             | Y (1)  | Y             | Y   | Y     | Y (2)      | N         |
| [Forgejo][]                 | Y (1)  | Y             | Y   | Y     | Y (2)      | N         |
| [Home-Assistant][]          | Y (1)  | Y             | N   | Y     | Y (2)      | N         |
| [Homepage][]                | Y (1)  | Y             | N   | Y     | Y (2)      | N         |
| [Jellyfin][]                | Y (1)  | Y             | Y   | Y     | Y (2)      | N         |
| [Karakeep][]                | Y (1)  | Y             | Y   | Y     | Y (2)      | N         |
| [Nextcloud Server][]        | Y (1)  | Y             | Y   | Y     | Y (2)      | P (3)     |
| [Open WebUI][]              | Y (1)  | Y             | Y   | Y     | Y (2)      | N         |
| [Pinchflat][]               | Y      | Y             | Y   | Y (4) | Y (5)      | N         |
| [Simple NixOS Mailserver][] | Y      | Y             | N   | Y     | Y          | N         |
| [Vaultwarden][]             | Y (1)  | Y             | Y   | Y     | Y (2)      | N         |

Legend: **N**: no but WIP; **P**: partial; **Y**: yes

1. Database and data files are backed up separately.
   This could lead to backups not being in sync.
   Any idea on how to fix this is welcomed!
2. Dashboard is common to all services.
3. Works but the traces are not exported to Grafana yet.
4. Uses LDAP indirectly through forward auth.

[*Arr]: services-arr.html
[Firefly-iii]: services-firefly-iii.html
[Forgejo]: services-forgejo.html
[Home-Assistant]: services-home-assistant.html
[Homepage]: services-homepage.html
[Jellyfin]: services-jellyfin.html
[Karakeep]: services-karakeep.html
[Nextcloud Server]: services-nextcloud.html
[Open WebUI]: services-open-webui.html
[Pinchflat]: services-pinchflat.html
[Simple NixOS Mailserver]: services-mailserver.html
[Vaultwarden]: services-vaultwarden.html

## Dashboard {#services-category-dashboard}

```{=include=} chapters html:into-file=//services-homepage.html
modules/services/homepage/docs/default.md
```

## Documents {#services-category-documents}

```{=include=} chapters html:into-file=//services-nextcloud.html
modules/services/nextcloud-server/docs/default.md
```

## Emails {#services-category-emails}

```{=include=} chapters html:into-file=//services-mailserver.html
modules/services/mailserver/docs/default.md
```

## Passwords {#services-category-passwords}

```{=include=} chapters html:into-file=//services-vaultwarden.html
modules/services/vaultwarden/docs/default.md
```

## Automation {#services-category-automation}

```{=include=} chapters html:into-file=//services-home-assistant.html
modules/services/home-assistant/docs/default.md
```

## AI {#services-category-ai}

```{=include=} chapters html:into-file=//services-karakeep.html
modules/services/karakeep/docs/default.md
```

```{=include=} chapters html:into-file=//services-open-webui.html
modules/services/open-webui/docs/default.md
```

## Code {#services-category-code}

```{=include=} chapters html:into-file=//services-forgejo.html
modules/services/forgejo/docs/default.md
```

## Media {#services-category-media}

```{=include=} chapters html:into-file=//services-arr.html
modules/services/arr/docs/default.md
```

```{=include=} chapters html:into-file=//services-jellyfin.html
modules/services/jellyfin/docs/default.md
```

```{=include=} chapters html:into-file=//services-pinchflat.html
modules/services/pinchflat/docs/default.md
```

## Finance {#services-category-finance}

```{=include=} chapters html:into-file=//services-firefly-iii.html
modules/services/firefly-iii/docs/default.md
```
