# Karakeep {#services-karakeep}

Defined in [`/modules/blocks/karakeep.nix`](@REPO@/modules/blocks/karakeep.nix),
found in the `selfhostblocks.nixosModules.karakeep` module.
See [the manual](usage.html#usage-flake) for how to import the module in your code.

This service sets up [Karakeep][] which is a bookmarking service powered by LLMs.
It integrates well with [Ollama][].

[Karakeep]: https://github.com/karakeep-app/karakeep
[Ollama]: https://ollama.com/

## Features {#services-karakeep-features}

- Declarative [LDAP](#services-karakeep-options-shb.karakeep.ldap) Configuration.
  - Needed LDAP groups are created automatically.
- Declarative [SSO](#services-karakeep-options-shb.karakeep.sso) Configuration.
  - When SSO is enabled, login with user and password is disabled.
  - Registration is enabled through SSO.
- Access through [subdomain](#services-karakeep-options-shb.karakeep.subdomain) using reverse proxy.
- Access through [HTTPS](#services-karakeep-options-shb.karakeep.ssl) using reverse proxy.
- [Backup](#services-karakeep-options-shb.karakeep.sso) through the [backup block](./blocks-backup.html).

## Usage {#services-karakeep-usage}

The following snippet assumes a few blocks have been setup already:

- the [secrets block](usage.html#usage-secrets) with SOPS,
- the [`shb.ssl` block](blocks-ssl.html#usage),
- the [`shb.lldap` block](blocks-lldap.html#blocks-lldap-global-setup).
- the [`shb.authelia` block](blocks-authelia.html#blocks-sso-global-setup).

```nix
{
  shb.karakeep = {
    enable = true;
    domain = "example.com";
    subdomain = "karakeep";

    ssl = config.shb.certs.certs.letsencrypt.${domain};

    sso = {
      enable = true;
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

      nextauthSecret.result = config.shb.sops.secret.nextauthSecret.result;
      sharedSecret.result = config.shb.sops.secret.oidcSecret.result;
      sharedSecretForAuthelia.result = config.shb.sops.secret.oidcAutheliaSecret.result;
    };
  };

  shb.sops.secret.nextauthSecret.request = config.shb.karakeep.sso.sharedSecret.request;
  shb.sops.secret.oidcSecret.request = config.shb.karakeep.sso.sharedSecret.request;
  shb.sops.secret.oidcAutheliaSecret = {
    request = config.shb.karakeep.sso.sharedSecretForAuthelia.request;
    settings.key = oidcSecret;
  };
}
```

Secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.

The [user](#services-open-webui-options-shb.open-webui.ldap.userGroup)
and [admin](#services-open-webui-options-shb.open-webui.ldap.adminGroup)
LDAP groups are created automatically.

## Integration with Ollama {#services-karakeep-ollama}

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
  services.open-webui = {
    environment.OLLAMA_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
  };
}
```

Notice we're using the upstream service here `services.open-webui`, not `shb.open-webui`.

## Options Reference {#services-karakeep-options}

```{=include=} options
id-prefix: services-karakeep-options-
list-id: selfhostblocks-services-karakeep-options
source: @OPTIONS_JSON@
```
