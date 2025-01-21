# LLDAP Block {#blocks-lldap}

Defined in [`/modules/blocks/lldap.nix`](@REPO@/modules/blocks/lldap.nix).

This block sets up a LDAP server using [LLDAP][].

[LLDAP]: https://github.com/lldap/lldap

## Tests {#blocks-lldap-tests}

Specific integration tests are defined in [`/test/blocks/lldap.nix`](@REPO@/test/blocks/lldap.nix).
The tests use a neat trick using specialization and switching configuration
to make sure changing the declarative configuration has the expected result.

## Provider Contracts {#blocks-lldap-contract-provider}

This block provides the following contract:

- [groups ldap contract](contracts-groups-ldap.html) under the [`shb.ldap.groups`][groups] option.
  It is tested with [contract tests][groups ldap contract tests].

[groups]: #blocks-lldap-options-shb.ldap.groups
[groups ldap contract tests]: @REPO@/test/contracts/groups-ldap.nix

## Usage {#blocks-lldap-usage}

### Manage groups {#blocks-lldap-usage-groups}

The following snippet will create group named "family" if it does not exist yet.
Also, all other groups will be deleted and only the "family" group will remain.

Note that the "admin" group, which is internal to LLDAP, will never be deleted.

```nix
{
  shb.ldap.groups = {
    family = {};
  };
}
```

Changing the configuration to the following will add a new group "friends":

```nix
{
  shb.ldap.groups = {
    family = {};
    friends = {};
  };
}
```

Switching back the configuration to the previous one will delete the group "friends":

```nix
{
  shb.ldap.groups = {
    family = {};
  };
}
```

Currently, only the empty attrset is supported as the value for a group.
This will change in the future when LLDAP supports custom group attributes.

### Manage users {#blocks-lldap-usage-users}

The following snippet creates a user and makes it a member of the "family" group.

```nix
{
  shb.ldap.users = {
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
    shb.ldap.users.dad.password.request;
}
```

The password field assumes usage of the [sops block][] to provide secrets
although any blocks providing the [secrets contract][] works too.

[sops block]: ./blocks-sops.html
[secrets contract]: ./contracts-secrets.html

The user is still editable through the UI.
That being said, any change will be overwritten next time the configuration is applied.
If instead you just want to set initial values,
there are fields for that:

```nix
{
  shb.ldap.users = {
    dad = {
      initialEmail = "dad@example.com";
      initialDisplayName = "Dad";
      initialFirstName = "First Name";
      initialLastName = "Last Name";
      initialGroups = [ "family" ];
      initialPassword.result = config.shb.sops.secret."dad".result;
    };
  };

  shb.sops.secret."dad".request =
    shb.ldap.users.dad.password.request;
}
```

Also, all fields apart from the email are optional, even the password.

Adding or removing groups to the `shb.ldap.users.<name>.groups` will make the user member of the groups listed in the option.

## Troubleshooting {#blocks-lldap-troubleshooting}

To see the logs, run `journalctl -u lldap.service`.

To see the trace of the GraphQL queries, set `shb.ldap.debug = true;`.

## Options Reference {#blocks-lldap-options}

```{=include=} options
id-prefix: blocks-lldap-options-
list-id: selfhostblocks-block-lldap-options
source: @OPTIONS_JSON@
```
