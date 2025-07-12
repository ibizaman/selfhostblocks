# LLDAP Block {#blocks-lldap}

Defined in [`/modules/blocks/lldap.nix`](@REPO@/modules/blocks/lldap.nix).

This block sets up an [LLDAP][] service for user and group management
across services.

[LLDAP]: https://github.com/lldap/lldap

## Global Setup {#blocks-lldap-global-setup}

```nix
shb.lldap = {
  enable = true;
  subdomain = "ldap";
  domain = "example.com";
  dcdomain = "dc=example,dc=com";

  ldapPort = 3890;
  webUIListenPort = 17170;

  jwtSecret.result = config.shb.sops.secret."lldap/jwt_secret".result;
  ldapUserPassword.result = config.shb.sops.secret."lldap/user_password".result;
};
shb.sops.secret."lldap/jwt_secret".request = config.shb.ldap.jwtSecret.request;
shb.sops.secret."lldap/user_password".request = config.shb.ldap.ldapUserPassword.request;
```

This assumes secrets are setup with SOPS
as mentioned in [the secrets setup section](usage.html#usage-secrets) of the manual.

## SSL {#blocks-lldap-ssl}

Using SSL is an important security practice, like always.
Using the [SSL block][], the configuration to add to the one above is:

[SSL block]: blocks-ssl.html

```nix
shb.certs.certs.letsencrypt.${domain}.extraDomains = [
  "${config.shb.lldap.subdomain}.${config.shb.lldap.domain}"
];

shb.ldap.ssl = config.shb.certs.certs.letsencrypt.${config.shb.lldap.domain};
```

## Restrict Access By IP {#blocks-lldap-restrict-access-by-ip}

For added security, you can restrict access to the LLDAP UI
by adding the following line:

```nix
shb.lldap.restrictAccessIPRange = "192.168.50.0/24";
```

## Manage User and Group {#blocks-lldap-manage-user-group}

Currently, managing users and groups must be done manually.
Work is in progress to make this declarative.

## Troubleshooting {#blocks-lldap-troubleshooting}

To increase logging verbosity, add:

```nix
shb.lldap.debug = true;
```

Note that verbosity is truly verbose here
so you will want to revert this at some point.

## Tests {#blocks-lldap-tests}

Specific integration tests are defined in [`/test/blocks/lldap.nix`](@REPO@/test/blocks/lldap.nix).

## Options Reference {#blocks-lldap-options}

```{=include=} options
id-prefix: blocks-lldap-options-
list-id: selfhostblocks-block-lldap-options
source: @OPTIONS_JSON@
```
