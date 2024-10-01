# Secret Contract {#secret-contract}

This NixOS contract represents a secret file
that must be created out of band - from outside the nix store -
and that must be placed in an expected location with expected permission.

More formally, this contract is made between a requester module - the one needing a secret -
and a provider module - the one creating the secret and making it available.

## Problem Statement {#secret-contract-problem}

Let's provide the [ldap SHB module][ldap-module] option `ldapUserPasswordFile`
with a secret managed by [sops-nix][].

[ldap-module]: TODO
[sops-nix]: TODO

Without the secret contract, configuring the option would look like so:

```nix
sops.secrets."ldap/user_password" = {
  sopsFile = ./secrets.yaml;
  mode = "0440";
  owner = "lldap";
  group = "lldap";
  restartUnits = [ "lldap.service" ];
};

shb.ldap.ldapUserPasswordFile = config.sops.secrets."ldap/user_password".path;
```

The problem this contract intends to fix is how to ensure
the end user knows what values to give to the
`mode`, `owner`, `group` and `restartUnits` options?

If lucky, the documentation of the option would tell them
or more likely, they will need to figure it out by looking
at the module source code.
Not a great user experience.

Now, with this contract, the configuration becomes:

```nix
sops.secrets."ldap/user_password" = config.shb.ldap.secret.ldapUserPassword.request // {
  sopsFile = ./secrets.yaml;
};

shb.ldap.ldapUserPassword.result.path = config.sops.secrets."ldap/user_password".path;
```

The issue is now gone at the expense of some plumbing.
The module maintainer is now in charge of describing
how the module expects the secret to be provided.

If taking advantage of the `sops.defaultSopsFile` option like so:

```nix
sops.defaultSopsFile = ./secrets.yaml;
```

Then the snippet above is even more simplified:

```nix
sops.secrets."ldap/user_password" = config.shb.ldap.secret.ldapUserPassword.request;

shb.ldap.ldapUserPassword.result.path = config.sops.secrets."ldap/user_password".path;
```

## Contract Reference {#secret-contract-options}

These are all the options that are expected to exist for this contract to be respected.

```{=include=} options
id-prefix: contracts-secret-options-
list-id: selfhostblocks-options
source: @OPTIONS_JSON@
```

## Usage {#secret-contract-usage}

A contract involves 3 parties:

- The implementer of a requester module.
- The implementer of a provider module.
- The end user which sets up the requester module and picks a provider implementation.

The usage of this contract is similarly separated into 3 sections.

### Requester Module {#secret-contract-usage-requester}

Here is an example module requesting two secrets through the `secret` contract.

```nix
{ config, ... }:
{
  options = {
    myservice = lib.mkOption {
      type = lib.types.submodule {
        options = {
          adminPassword = contracts.secret.mkOption {
            owner = "myservice";
            group = "myservice";
            mode = "0440";
            restartUnits = [ "myservice.service" ];
          };
          databasePassword = contracts.secret.mkOption {
            owner = "myservice";
            # group defaults to "root"
            # mode defaults to "0400"
            restartUnits = [ "myservice.service" "mysql.service" ];
          };
        };
      };
    };
  };

  config = {
    // Do something with the secrets, available at:
    // config.myservice.adminPassword.result.path
    // config.myservice.databasePassword.result.path
  };
};
```

### Provider Module {#secret-contract-usage-provider}

Now, on the other side, we have a module that uses those options and provides a secret.
Let's assume such a module is available under the `secretservice` option
and that one can create multiple instances.

```nix
{ config, ... }:
{
  options = {
    secretservice = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          mode = lib.mkOption {
            description = "Mode of the secret file.";
            type = lib.types.str;
          };

          owner = lib.mkOption {
            description = "Linux user owning the secret file.";
            type = lib.types.str;
          };

          group = lib.mkOption {
            description = "Linux group owning the secret file.";
            type = lib.types.str;
          };

          restartUnits = lib.mkOption {
            description = "Systemd units to restart after the secret is updated.";
            type = lib.types.listOf lib.types.str;
          };

          path = lib.mkOption {
            description = "Path where the secret file will be located.";
            type = lib.types.str;
          };

          // The contract allows more options to be defined to accomodate specific implementations.
          secretFile = lib.mkOption {
            description = "File containing the encrypted secret.";
            type = lib.types.path;
          };
        };
      });
    };
  };
}
```

### End User {#secret-contract-usage-enduser}

The end user's responsibility is now to do some plumbing.

They will setup the provider module - here `secretservice` - with the options set by the requester module,
while also setting other necessary options to satisfy the provider service.

```nix
secretservice.adminPassword = myservice.secret.adminPassword.request // {
  secretFile = ./secret.yaml;
};

secretservice.databasePassword = myservice.secret.databasePassword.request // {
  secretFile = ./secret.yaml;
};
```

Assuming the `secretservice` module accepts default options,
the above snippet could be reduced to:

```nix
secretservice.default.secretFile = ./secret.yaml;

secretservice.adminPassword = myservice.secret.adminPassword.request;
secretservice.databasePassword = myservice.secret.databasePassword.request;
```

Then they will setup the requester module - here `myservice` - with the result of the provider module.

```nix
myservice.secret.adminPassword.result.path = secretservice.adminPassword.result.path;

myservice.secret.databasePassword.result.path = secretservice.adminPassword.result.path;
```
