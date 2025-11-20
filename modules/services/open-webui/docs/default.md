# Open-WebUI Service {#services-open-webui}

Defined in [`/modules/blocks/open-webui.nix`](@REPO@/modules/blocks/open-webui.nix),
found in the `selfhostblocks.nixosModules.open-webui` module.
See [the manual](usage.html#usage-flake) for how to import the module in your code.

This service sets up [Open WebUI][] which provides a frontend to various LLMs.

[Open WebUI]: https://docs.openwebui.com/

## Features {#services-open-webui-features}

- Telemetry disabled.
- Skip onboarding through custom patch.
- Declarative [LDAP](#services-open-webui-options-shb.open-webui.ldap) Configuration.
  - Needed LDAP groups are created automatically.
- Declarative [SSO](#services-open-webui-options-shb.open-webui.sso) Configuration.
  - When SSO is enabled, login with user and password is disabled.
  - Registration is enabled through SSO.
  - Correct error message for unauthorized user through custom patch.
- Access through [subdomain](#services-open-webui-options-shb.open-webui.subdomain) using reverse proxy.
- Access through [HTTPS](#services-open-webui-options-shb.open-webui.ssl) using reverse proxy.
- [Backup](#services-open-webui-options-shb.open-webui.sso) through the [backup block](./blocks-backup.html).

## Usage {#services-open-webui-usage}

The following snippet assumes a few blocks have been setup already:

- the [secrets block](usage.html#usage-secrets) with SOPS,
- the [`shb.ssl` block](blocks-ssl.html#usage),
- the [`shb.lldap` block](blocks-lldap.html#blocks-lldap-global-setup).
- the [`shb.authelia` block](blocks-authelia.html#blocks-sso-global-setup).

```nix
{
  shb.open-webui = {
    enable = true;
    domain = "example.com";
    subdomain = "open-webui";

    ssl = config.shb.certs.certs.letsencrypt.${domain};

    sso = {
      enable = true;
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

      sharedSecret.result = config.shb.sops.secret.oidcSecret.result;
      sharedSecretForAuthelia.result = config.shb.sops.secret.oidcAutheliaSecret.result;
    };
  };

  shb.sops.secret."open-webui/oidcSecret".request = config.shb.open-webui.sso.sharedSecret.request;
  shb.sops.secret."open-webui/oidcAutheliaSecret" = {
    request = config.shb.open-webui.sso.sharedSecretForAuthelia.request;
    settings.key = "open-webui/oidcSecret";
  };
}
```

Secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.

The [user](#services-open-webui-options-shb.open-webui.ldap.userGroup)
and [admin](#services-open-webui-options-shb.open-webui.ldap.adminGroup)
LDAP groups are created automatically.

## Integration with OLLAMA {#services-open-webui-ollama}

Assuming ollama is enabled, it will be available on port `config.services.ollama.port`.
The following snippet sets up acceleration using an AMD (i)GPU and loads some models.

```nix
{
  services.ollama = {
    enable = true;

    # https://wiki.nixos.org/wiki/Ollama#AMD_GPU_with_open_source_driver
    acceleration = "rocm";

    # https://ollama.com/library
    loadModels = [
      "deepseek-r1:1.5b"
      "llama3.2:3b"
      "llava:7b"
      "mxbai-embed-large:335m"
      "nomic-embed-text:v1.5"
    ];
  };
}
```

Integrating with the ollama service is done with:

```nix
{
  shb.open-webui = {
    environment.OLLAMA_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
  };
}
```

## Backup {#services-open-webui-usage-backup}

Backing up Open-Webui using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."open-webui" = {
  request = config.shb.open-webui.backup;
  settings = {
    enable = true;
  };
};
```

The name `"open-webui"` in the `instances` can be anything.
The `config.shb.open-webui.backup` option provides what directories to backup.
You can define any number of Restic instances to backup Open WebUI multiple times.

## Options Reference {#services-open-webui-options}

```{=include=} options
id-prefix: services-open-webui-options-
list-id: selfhostblocks-services-open-webui-options
source: @OPTIONS_JSON@
```
