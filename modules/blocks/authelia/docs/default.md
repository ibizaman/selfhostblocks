# Authelia Block {#blocks-authelia}

Defined in [`/modules/blocks/authelia.nix`](@REPO@/modules/blocks/authelia.nix).

This block sets up an [Authelia][] service for Single-Sign On integration.

[Authelia]: https://www.authelia.com/

Compared to the upstream nixpkgs module, this module is tightly integrated
with SHB which allows easy configuration of SSO with [OIDC integration](#blocks-authelia-shb-oidc)
as well as some extensive [troubleshooting](#blocks-authelia-troubleshooting) features.

Note that forward authentication is configured with the [nginx block](blocks-nginx.html#blocks-nginx-usage-shbforwardauth).

## Global Setup {#blocks-authelia-global-setup}

Authelia cannot work without SSL and LDAP.
So setting up the Authelia block requires to setup the [SSL block][] first
and the [LLDAP block][] first.

[SSL block]: blocks-ssl.html
[LLDAP block]: blocks-lldap.html

SSL is required to encrypt the communication and LDAP is used to handle users and group assignments.
Authelia will allow access to a given resource only if the user that is authenticated
is a member of the corresponding LDAP group.

Afterwards, assuming the LDAP service runs on the same machine,
the Authelia configuration can be done with:

```nix
shb.authelia = {
  enable = true;
  domain = "example.com";
  subdomain = "auth";
  ssl = config.shb.certs.certs.letsencrypt."example.com";

  ldapHostname = "127.0.0.1";
  ldapPort = config.shb.lldap.ldapPort;
  dcdomain = config.shb.lldap.dcdomain;

  smtp = {
    host = "smtp.eu.mailgun.org";
    port = 587;
    username = "postmaster@mg.example.com";
    from_address = "authelia@example.com";
    password.result = config.shb.sops.secret."authelia/smtp_password".result;
  };

  secrets = {
    jwtSecret.result = config.shb.sops.secret."authelia/jwt_secret".result;
    ldapAdminPassword.result = config.shb.sops.secret."authelia/ldap_admin_password".result;
    sessionSecret.result = config.shb.sops.secret."authelia/session_secret".result;
    storageEncryptionKey.result = config.shb.sops.secret."authelia/storage_encryption_key".result;
    identityProvidersOIDCHMACSecret.result = config.shb.sops.secret."authelia/hmac_secret".result;
    identityProvidersOIDCIssuerPrivateKey.result = config.shb.sops.secret."authelia/private_key".result;
  };
};

shb.certs.certs.letsencrypt."example.com".extraDomains = [ "auth.example.com" ];

shb.sops.secret."authelia/jwt_secret".request = config.shb.authelia.secrets.jwtSecret.request;
shb.sops.secret."authelia/ldap_admin_password" = {
  request = config.shb.authelia.secrets.ldapAdminPassword.request;
  settings.key = "lldap/user_password";
};
shb.sops.secret."authelia/session_secret".request = config.shb.authelia.secrets.sessionSecret.request;
shb.sops.secret."authelia/storage_encryption_key".request = config.shb.authelia.secrets.storageEncryptionKey.request;
shb.sops.secret."authelia/hmac_secret".request = config.shb.authelia.secrets.identityProvidersOIDCHMACSecret.request;
shb.sops.secret."authelia/private_key".request = config.shb.authelia.secrets.identityProvidersOIDCIssuerPrivateKey.request;
shb.sops.secret."authelia/smtp_password".request = config.shb.authelia.smtp.password.request;
```

This assumes secrets are setup with SOPS
as mentioned in [the secrets setup section](usage.html#usage-secrets) of the manual.
It's a bit annoying to setup all those secrets but it's only necessary once.
Use `nix run nixpkgs#openssl -- rand -hex 64` to generate them.

Crucially, the `shb.authelia.secrets.ldapAdminPasswordFile` must be the same
as the `shb.lldap.ldapUserPassword` defined for the [LLDAP block][].
This is done using Sops' `key` option.

## SHB OIDC integration {#blocks-authelia-shb-oidc}

For services [provided by SelfHostBlocks][services] that handle [OIDC integration][OIDC],
integrating with this block is done by configuring the service itself
and linking it to this Authelia block through the `endpoint` option
and by sharing a secret:

[services]: services.html
[OIDC]: https://openid.net/developers/how-connect-works/

```nix
shb.<service>.sso = {
  enable = true;
  endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

  secret.result = config.shb.sops.secret."<service>/sso/secret".result;
  secretForAuthelia.result = config.shb.sops.secret."<service>/sso/secretForAuthelia".result;
};

shb.sops.secret."<service>/sso/secret".request = config.shb.<service>.sso.secret.request;
shb.sops.secret."<service>/sso/secretForAuthelia" = {
  request = config.shb.<service>.sso.secretForAuthelia.request;
  settings.key = "<service>/sso/secret";
};
```

To share a secret between the service and Authelia,
we generate a secret with `nix run nixpkgs#openssl -- rand -hex 64` under `<service>/sso/secret`
then we ask Sops to use the same password for `<service>/sso/secretForAuthelia`
thanks to the `settings.key` option.
The difference between both secrets is one if owned by the `authelia` user
while the other is owned by the user of the `<service`> we are configuring.

## OIDC Integration {#blocks-authelia-oidc}

To integrate a service handling OIDC integration not provided by SelfHostBlocks with this Authelia block,
the necessary configuration is:

```nix
shb.authelia.oidcClients = [
  {
    client_id = "<service>";
    client_secret.source = config.shb.sops.secret."<service>/sso/secretForAuthelia".response.path;
    scopes = [ "openid" "email" "profile" ];
    redirect_uris = [
      "<provided by service documentation>"
    ];
  }
];

shb.sops.secret."<service>/sso/secret".request = {
  owner = "<service_user>";
};
shb.sops.secret."<service>/sso/secretForAuthelia" = {
  request.owner = "authelia";
  settings.key = "<service>/sso/secret";
};
```

As in the previous section, we create a shared secret using Sops'
`settings.key` option.

The configuration for the service itself is much dependent on the service itself.
For example for [open-webui][], the configuration looks like so:

[open-webui]: https://search.nixos.org/options?query=services.open-webui

```nix
services.open-webui.environment = {
  ENABLE_SIGNUP = "False";
  WEBUI_AUTH = "True";
  ENABLE_FORWARD_USER_INFO_HEADERS = "True";
  ENABLE_OAUTH_SIGNUP = "True";
  OAUTH_UPDATE_PICTURE_ON_LOGIN = "True";
  OAUTH_CLIENT_ID = "open-webui";
  OAUTH_CLIENT_SECRET = "<raw secret>";
  OPENID_PROVIDER_URL = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}/.well-known/openid-configuration";
  OAUTH_PROVIDER_NAME = "Single Sign-On";
  OAUTH_SCOPES = "openid email profile";
  OAUTH_ALLOWED_ROLES = "open-webui_user";
  OAUTH_ADMIN_ROLES = "open-webui_admin";
  ENABLE_OAUTH_ROLE_MANAGEMENT = "True";
};

shb.authelia.oidcClients = [
  {
    client_id = "open-webui";
    client_secret.source = config.shb.sops.secret."open-webui/sso/secretForAuthelia".response.path;
    scopes = [ "openid" "email" "profile" ];
    redirect_uris = [
      "<provided by service documentation>"
    ];
  }
];

shb.sops.secret."open-webui/sso/secret".request = {
  owner = "open-webui";
};
shb.sops.secret."open-webui/sso/secretForAuthelia" = {
  request.owner = "authelia";
  settings.key = "open-webui/sso/secret";
};
```

Here, there is no way to give a path for the `OAUTH_CLIENT_SECRET`,
we are obligated to pass the raw secret which is a very bad idea.
There are ways around this but they are out of scope for this section.
Inspiration can be taken from SelfHostBlocks' source code.

To access the UI, we will need to create an `open-webui_user` and
`open-webui_admin` LDAP group and assign our user to it.

## Forward Auth {#blocks-authelia-forward-auth}

Forward authentication is provided by the [nginx block](blocks-nginx.html#blocks-nginx-usage-ssl).

## Troubleshooting {#blocks-authelia-troubleshooting}

Set the [debug][opt-debug] option to `true` to:

[opt-debug]: #blocks-authelia-options-shb.authelia.debug

- Set logging level to `"debug"`.
- Add an [shb.mitmdump][] instance in front of Authelia
  which prints all requests and responses headers and body
  to the systemd service `mitmdump-authelia-${config.shb.authelia.subdomain}.${config.shb.authelia.domain}.service`.

[shb.mitmdump]: ./blocks-mitmdump.html

## Tests {#blocks-authelia-tests}

Specific integration tests are defined in [`/test/blocks/authelia.nix`](@REPO@/test/blocks/authelia.nix).

## Options Reference {#blocks-authelia-options}

```{=include=} options
id-prefix: blocks-authelia-options-
list-id: selfhostblocks-block-authelia-options
source: @OPTIONS_JSON@
```
