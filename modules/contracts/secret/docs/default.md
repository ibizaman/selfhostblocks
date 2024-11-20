# Secret Contract {#secret-contract}

This NixOS contract represents a secret file
that must be created out of band - from outside the nix store -
and that must be placed in an expected location with expected permission.

More formally, this contract is made between a requester module - the one needing a secret -
and a provider module - the one creating the secret and making it available.

## Motivation {#secret-contract-motivation}

Let's provide the [ldap SHB module][ldap-module] option `ldapUserPasswordFile`
with a secret managed by [sops-nix][].

[ldap-module]: TODO
[sops-nix]: TODO

Without the secret contract, configuring the option would look like so:

```nix
sops.secrets."ldap/user_password" = {
  mode = "0440";
  owner = "lldap";
  group = "lldap";
  restartUnits = [ "lldap.service" ];
  sopsFile = ./secrets.yaml;
};

shb.ldap.userPassword.result = config.sops.secrets."ldap/user_password".result;
```

The problem this contract intends to fix is how to ensure
the end user knows what values to give to the
`mode`, `owner`, `group` and `restartUnits` options?

If lucky, the documentation of the option would tell them
or more likely, they will need to figure it out by looking
at the module source code.
Not a great user experience.

Now, with this contract, a layer on top of `sops` is added which is found under `shb.sops`.
The configuration then becomes:

```nix
shb.sops.secrets."ldap/user_password" = {
  request = config.shb.ldap.userPassword.request;
  settings.sopsFile = ./secrets.yaml;
};

shb.ldap.userPassword.result = config.shb.sops.secrets."ldap/user_password".result;
```

The issue is now gone as the responsibility falls
on the module maintainer
for describing how the secret should be provided.

If taking advantage of the `sops.defaultSopsFile` option like so:

```nix
sops.defaultSopsFile = ./secrets.yaml;
```

Then the snippet above is even more simplified:

```nix
shb.sops.secrets."ldap/user_password".request = config.shb.ldap.userPassword.request;

shb.ldap.userPassword.result = config.shb.sops.secrets."ldap/user_password".result;
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
let
  inherit (lib) mkOption;
  inherit (lib.types) submodule;
in
{
  options = {
    myservice = mkOption {
      type = submodule {
        options = {
          adminPassword = contracts.secret.mkRequester {
            owner = "myservice";
            group = "myservice";
            mode = "0440";
            restartUnits = [ "myservice.service" ];
          };
          databasePassword = contracts.secret.mkRequester {
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
let
  inherit (lib) mkOption;
  inherit (lib.types) attrsOf submodule;

  contracts = pkgs.callPackage ./contracts {};
in
{
  options.secretservice.secret = mkOption {
    description = "Secret following the secret contract.";
    default = {};
    type = attrsOf (submodule ({ name, options, ... }: {
      options = contracts.secret.mkProvider {
        settings = mkOption {
          description = ''
            Settings specific to the secrets provider.
          '';

          type = submodule {
            options = {
              secretFile = lib.mkOption {
                description = "File containing the encrypted secret.";
                type = lib.types.path;
              };
            };
          };
        };

        resultCfg = {
          path = "/run/secrets/${name}";
          pathText = "/run/secrets/<name>";
        };
      };
    }));
  };

  config = {
    // ...
  };
}
```

### End User {#secret-contract-usage-enduser}

The end user's responsibility is now to do some plumbing.

They will setup the provider module - here `secretservice` - with the options set by the requester module,
while also setting other necessary options to satisfy the provider service.
And then they will give back the result to the requester module `myservice`.

```nix
secretservice.secret."adminPassword" = {
  request = myservice.adminPasswor".request;
  settings.secretFile = ./secret.yaml;
};
myservice.adminPassword.result = secretservice.secret."adminPassword".result;

secretservice.secret."databasePassword" = {
  request = myservice.databasePassword.request;
  settings.secretFile = ./secret.yaml;
};
myservice.databasePassword.result = secretservice.service."databasePassword".result;
```

Assuming the `secretservice` module accepts default options,
the above snippet could be reduced to:

```nix
secretservice.default.secretFile = ./secret.yaml;

secretservice.secret."adminPassword".request = myservice.adminPasswor".request;
myservice.adminPassword.result = secretservice.secret."adminPassword".result;

secretservice.secret."databasePassword".request = myservice.databasePassword.request;
myservice.databasePassword.result = secretservice.service."databasePassword".result;
```

The plumbing of request from the requester to the provider
and then the result from the provider back to the requester
is quite explicit in this snippet.
