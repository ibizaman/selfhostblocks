# Vaultwarden Service {#services-vaultwarden}

Defined in [`/modules/services/vaultwarden.nix`](@REPO@/modules/services/vaultwarden.nix).

This NixOS module is a service that sets up a [Vaultwarden Server](https://github.com/dani-garcia/vaultwarden).

## Features {#services-vaultwarden-features}

- Access through subdomain using reverse proxy.
- Access through HTTPS using reverse proxy.
- Automatic setup of Redis database for caching.
- Backup of the data directory through the [backup block](./blocks-backup.html).
- [Integration Tests](@REPO@/test/services/vaultwarden.nix)
  - Tests /admin can only be accessed when authenticated with SSO.
- Access to advanced options not exposed here thanks to how NixOS modules work.

## Usage {#services-vaultwarden-usage}

### Secrets {#services-vaultwarden-secrets}

All the secrets should be readable by the vaultwarden user.

Secrets should not be stored in the nix store. If you're using
[sops-nix](https://github.com/Mic92/sops-nix) and assuming your secrets file is located at
`./secrets.yaml`, you can define a secret with:

```nix
sops.secrets."vaultwarden/db" = {
  sopsFile = ./secrets.yaml;
  mode = "0400";
  owner = "vaultwarden";
  group = "postgres";
  restartUnits = [ "vaultwarden.service" ];
};
```

Then you can use that secret:

```nix
shb.vaultwarden.databasePasswordFile = config.sops.secrets."vaultwarden/db".path;
```

### SSO {#services-vaultwarden-sso}

To protect the `/admin` endpoint, we use SSO.
This requires the SSL, LDAP and SSO block to be configured.
Follow those links first if needed.

```nix
let
  domain = <...>;
in
shb.vaultwarden = {
  enable = true;
  inherit domain;
  subdomain = "vaultwarden";
  ssl = config.shb.certs.certs.letsencrypt.${domain};
  port = 8222;
  authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
  databasePasswordFile = config.sops.secrets."vaultwarden/db".path;
  smtp = {
    host = "smtp.eu.mailgun.org";
    port = 587;
    username = "postmaster@mg.${domain}";
    from_address = "authelia@${domain}";
    passwordFile = config.sops.secrets."vaultwarden/smtp".path;
  };
};

sops.secrets."vaultwarden/db" = {
  sopsFile = ./secrets.yaml;
  mode = "0440";
  owner = "vaultwarden";
  group = "postgres";
  restartUnits = [ "vaultwarden.service" "postgresql.service" ];
};
sops.secrets."vaultwarden/smtp" = {
  sopsFile = ./secrets.yaml;
  mode = "0400";
  owner = "vaultwarden";
  group = "vaultwarden";
  restartUnits = [ "vaultwarden.service" ];
};
```

### ZFS {#services-vaultwarden-zfs}

Integration with the ZFS block allows to automatically create the relevant datasets.

```nix
shb.zfs.datasets."vaultwarden" = config.shb.vaultwarden.mount;
shb.zfs.datasets."postgresql".path = "/var/lib/postgresql";
```

## Maintenance {#services-vaultwarden-maintenance}

No command-line tool is provided to administer Vaultwarden.

Instead, the admin section can be found at the `/admin` endpoint.

## Debug {#services-backup-debug}

In case of an issue, check the logs of the `vaultwarden.service` systemd service.

Enable verbose logging by setting the `shb.vaultwarden.debug` boolean to `true`.

Access the database with `sudo -u vaultwarden psql`.

## Options Reference {#services-vaultwarden-options}

```{=include=} options
id-prefix: services-vaultwarden-options-
list-id: selfhostblocks-vaultwarden-options
source: @OPTIONS_JSON@
```
