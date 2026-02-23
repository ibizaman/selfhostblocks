# LLDAP Block {#blocks-lldap}

Defined in [`/modules/blocks/lldap.nix`](@REPO@/modules/blocks/lldap.nix).

This block sets up an [LLDAP][] service for user and group management
across services.

[LLDAP]: https://github.com/lldap/lldap

## Features {#blocks-lldap-features}

- Integration with the [dashboard contract](contracts-dashboard.html) for displaying user facing application in a dashboard. [Manual](#blocks-lldap-usage-applicationdashboard)

## Usage {#blocks-lldap-usage}

### Initial Configuration {#blocks-lldap-usage-configuration}

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
shb.sops.secret."lldap/jwt_secret".request = config.shb.lldap.jwtSecret.request;
shb.sops.secret."lldap/user_password".request = config.shb.lldap.ldapUserPassword.request;
```

This assumes secrets are setup with SOPS
as mentioned in [the secrets setup section](usage.html#usage-secrets) of the manual.

### SSL {#blocks-lldap-usage-ssl}

Using SSL is an important security practice, like always.
Using the [SSL block][], the configuration to add to the one above is:

[SSL block]: blocks-ssl.html

```nix
shb.certs.certs.letsencrypt.${domain}.extraDomains = [
  "${config.shb.lldap.subdomain}.${config.shb.lldap.domain}"
];

shb.lldap.ssl = config.shb.certs.certs.letsencrypt.${config.shb.lldap.domain};
```

### Restrict Access By IP {#blocks-lldap-usage-restrict-access-by-ip}

For added security, you can restrict access to the LLDAP UI
by adding the following line:

```nix
shb.lldap.restrictAccessIPRange = "192.168.50.0/24";
```

### Application Dashboard {#blocks-lldap-usage-applicationdashboard}

Integration with the [dashboard contract](contracts-dashboard.html) is provided
by the [dashboard option](#blocks-lldap-options-shb.lldap.dashboard).

For example using the [Homepage](services-homepage.html) service:

```nix
{
  shb.homepage.servicesGroups.Admin.services.LLDAP = {
    sortOrder = 2;
    dashboard.request = config.shb.lldap.dashboard.request;
  };
}
```

## Manage Groups {#blocks-lldap-manage-groups}

The following snippet will create group named "family" if it does not exist yet.
Also, all other groups will be deleted and only the "family" group will remain.

Note that the `lldap_admin`, `lldap_password_manager` and `lldap_strict_readonly` groups, which are internal to LLDAP, will always exist.

If you want existing groups not declared in the `shb.lldap.ensureGroups` to be deleted,
set [`shb.lldap.enforceGroups`](#blocks-lldap-options-shb.lldap.enforceGroups) to `false`.

```nix
{
  shb.lldap.ensureGroups = {
   family = {};
  };
}
```

Changing the configuration to the following will add a new group "friends":

```nix
{
  shb.lldap.ensureGroups = {
    family = {};
    friends = {};
  };
}
```

Switching back the configuration to the previous one will delete the group "friends":

```nix
{
  shb.lldap.ensureGroups = {
    family = {};
  };
}
```

Custom fields can be added to groups as long as they are added to the `ensureGroupFields` field:

```nix
shb.lldap = {
  ensureGroupFields = {
    mygroupattribute = {
      attributeType = "STRING";
    };
  };

  ensureGroups = {
    family = {
      mygroupattribute = "Managed by NixOS";
    };
  };
};
```

## Manage Users {#blocks-lldap-manage-users}

The following snippet creates a user and makes it a member of the "family" group.

Note the following behavior:

- New users will be created following the `shb.lldap.ensureUsers` option.
- Existing users will be updated, their password included, if they are mentioned in the `shb.lldap.ensureUsers` option.
- Existing users not declared in the `shb.lldap.ensureUsers` will be left as-is.
- User memberships to groups not declared in their respective `shb.lldap.ensureUsers.<name>.groups`.

If you want existing users not declared in the `shb.lldap.ensureUsers` to be deleted,
set [`shb.lldap.enforceUsers`](#blocks-lldap-options-shb.lldap.enforceUsers) to `true`.

If you want memberships to groups not declared in the respective
`shb.lldap.ensureUsers.<name>.groups` option to be deleted,
set [`shb.lldap.enforceUserMemberships`](#blocks-lldap-options-shb.lldap.enforceUserMemberships) `true`.

```nix
{
  shb.lldap.ensureUsers = {
    dad = {
      email = "dad@example.com";
      displayName = "Dad";
      firstName = "First Name";
      lastName = "Last Name";
      groups = [ "family" ];
      password.result = config.shb.sops.secret."dad".result;
    };
  };

  shb.sops.secret."dad".request =
    config.shb.lldap.ensureUsers.dad.password.request;
}
```

The password field assumes usage of the [sops block][] to provide secrets
although any blocks providing the [secrets contract][] works too.

[sops block]: blocks-sops.html
[secrets contract]: contracts-secrets.html

The user is still editable through the UI.
That being said, any change will be overwritten next time the configuration is applied.

## Troubleshooting {#blocks-lldap-troubleshooting}

To increase logging verbosity and see the trace of the GraphQL queries, add:

```nix
shb.lldap.debug = true;
```

Note that verbosity is truly verbose here
so you will want to revert this at some point.

To see the logs, then run `journalctl -u lldap.service`.

Setting the `debug` option to `true` will also
add an [shb.mitmdump][] instance in front of the LLDAP [web UI port](#blocks-lldap-options-shb.lldap.webUIListenPort)
which prints all requests and responses headers and body
to the systemd service `mitmdump-lldap.service`. Note the you won't
see the query done using something like `ldapsearch` since those
go through the [`LDAP` port](#blocks-lldap-options-shb.lldap.ldapPort).

[shb.mitmdump]: ./blocks-mitmdump.html

## Tests {#blocks-lldap-tests}

Specific integration tests are defined in [`/test/blocks/lldap.nix`](@REPO@/test/blocks/lldap.nix).

## Options Reference {#blocks-lldap-options}

```{=include=} options
id-prefix: blocks-lldap-options-
list-id: selfhostblocks-block-lldap-options
source: @OPTIONS_JSON@
```
