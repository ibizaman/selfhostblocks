<!-- Read these docs at https://shb.skarabox.com -->
# Preface {#preface}

::: {.note}
Self Host Blocks is hosted on [GitHub](https://github.com/ibizaman/selfhostblocks).
If you encounter problems or bugs then please report them on the [issue
tracker](https://github.com/ibizaman/selfhostblocks/issues).

Feel free to join the dedicated Matrix room
[matrix.org#selfhostblocks](https://matrix.to/#/#selfhostblocks:matrix.org).
:::

Self Host Blocks intends to help you self host any service you would like
with best practices out of the box.

Compared to the stock nixpkgs experience, Self Host Blocks provides
an unified interface to setup common dependencies, called blocks
in this project:

- reverse proxy
- TLS certificate management
- serving service under subdomain
- backup
- LDAP
- SSO.

Compare the configuration for Nextcloud and Forgejo.
The following snippets focus on similitudes and assume the relevant blocks are configured off-screen.

```nix
shb.nextcloud = {
  enable = true;
  subdomain = "nextcloud";
  domain = "example.com";

  ssl = config.shb.certs.certs.letsencrypt.${domain};

  apps.ldap = {
    enable = true;
    host = "127.0.0.1";
    port = config.shb.ldap.ldapPort;
    dcdomain = config.shb.ldap.dcdomain;
    adminPassword.result = config.shb.sops.secrets."nextcloud/ldap/admin_password".result;
  };
  apps.sso = {
    enable = true;
    endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

    secret.result = config.shb.sops.secrets."nextcloud/sso/secret".result;
    secretForAuthelia.result = config.shb.sops.secrets."nextcloud/sso/secretForAuthelia".result;
  };
};
```

```nix
shb.forgejo = {
  enable = true;
  subdomain = "forgejo";
  domain = "example.com";

  ssl = config.shb.certs.certs.letsencrypt.${domain};

  ldap = {
    enable = true;
    host = "127.0.0.1";
    port = config.shb.ldap.ldapPort;
    dcdomain = config.shb.ldap.dcdomain;
    adminPassword.result = config.shb.sops.secrets."nextcloud/ldap/admin_password".result;
  };

  sso = {
    enable = true;
    endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

    secret.result = config.shb.sops.secrets."forgejo/sso/secret".result;
    secretForAuthelia.result = config.shb.sops.secrets."forgejo/sso/secretForAuthelia".result;
  };
};
```

SHB facilitates testing NixOS and slowly switching an existing installation to NixOS.

To achieve this, SHB pioneers [contracts][]
which allows you, the final user, to be more in control of which piece go where.
This lets you choose, for example,
any reverse proxy you want or any database you want,
without requiring work from maintainers of the services you want to self host.

[contracts]: contracts.html

To achieve this, Self Host Blocks provides building blocks
which each provide part of what a self hosted app should do (SSO, HTTPS, etc.).
It also provides some services that are already integrated with all those building blocks.

- You are new to self hosting and want pre-configured services to deploy easily.
  Look at the [services section](services.html).
- You are a seasoned self-hoster but want to enhance some services you deploy already.
  Go to the [blocks section](blocks.html).
- You are a user of Self Host Blocks but would like to use your own implementation for a block.
  Go to the [contracts section](https://shb.skarabox.com/contracts.html).

Self Host Blocks uses the full power of NixOS modules to achieve these goals.
Blocks and service are both NixOS modules.
