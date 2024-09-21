# Secret Contract {#secret-contract}

This NixOS contract represents a secret file
that must be created out of band, from outside the nix store,
and that must be placed in an expected location with expected permission.

It is a contract between a service that needs a secret
and a service that will provide the secret.
All options in this contract should be set by the former.
The latter will then use the values of those options to know where to produce the file.

## Contract Reference {#secret-contract-options}

These are all the options that are expected to exist for this contract to be respected.

```{=include=} options
id-prefix: contracts-secret-options-
list-id: selfhostblocks-options
source: @OPTIONS_JSON@
```

## Usage {#secret-contract-usage}

A service that needs access to a secret will provide one or more `secret` option.

Here is an example module defining two `secret` options:

```nix
{
  options = {
    myservice.secret = lib.mkOption {
      type = lib.types.submodule {
        options = {
          adminPassword = lib.mkOption {
            type = contracts.secret;
            readOnly = true;
            default = {
              owner = "myservice";
              group = "myservice";
              mode = "0440";
              restartUnits = [ "myservice.service" ];
            };
          };
          databasePassword = lib.mkOption {
            type = contracts.secret;
            readOnly = true;
            default = {
              owner = "myservice";
              restartUnits = [ "myservice.service" "mysql.service" ];
            };
          };
        };
      };
    };
  };
};
```

As you can see, NixOS modules are a bit abused to make contracts work.
Default values are set as well as the `readOnly` attribute to ensure those values stay as defined.

Now, on the other side we have a service that uses these `secret` options and provides the secrets
Let's assume such a module is available under the `secretservice` option
and that one can create multiple instances under `secretservice.instances`.
Then, to actually provide the secrets defined above, one would write:

```nix
secretservice.instances.adminPassword = myservice.secret.adminPassword // {
  enable = true;

  secretFile = ./secret.yaml;

  # ... Other options specific to secretservice.
};

secretservice.instances.databasePassword = myservice.secret.databasePassword // {
  enable = true;

  secretFile = ./secret.yaml;

  # ... Other options specific to secretservice.
};
```

Assuming the `secretservice` module accepts default options,
the above snippet could be reduced to:

```nix
secretservice.default.secretFile = ./secret.yaml;

secretservice.instances.adminPassword = myservice.secret.adminPassword;
secretservice.instances.databasePassword = myservice.secret.databasePassword;
```

### With sops-nix {#secret-contract-usage-sopsnix}

For a concrete example, let's provide the [ldap SHB module][ldap-module] option `ldapUserPasswordFile`
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

We can already see the problem here.
How does the end user know what values to give to the
`mode`, `owner`, `group` and `restartUnits` options?
If lucky, the documentation of the option would tell them
or more likely, they will need to figure it out by looking
at the module source code. Not a great user experience.

Now, with this contract, the configuration becomes:

```nix
sops.secrets."ldap/user_password" = config.shb.ldap.secret.ldapUserPasswordFile // {
  sopsFile = ./secrets.yaml;
};

shb.ldap.ldapUserPasswordFile = config.sops.secrets."ldap/user_password".path;
```

The issue is now gone.
The module maintainer is now in charge of describing
how the module expects the secret to be provided.

If taking advantage of the `sops.defaultSopsFile` option like so:

```nix
sops.defaultSopsFile = ./secrets.yaml;
```

Then the snippet above is even more simplified:

```nix
sops.secrets."ldap/user_password" = config.shb.ldap.secret.ldapUserPasswordFile;

shb.ldap.ldapUserPasswordFile = config.sops.secrets."ldap/user_password".path;
```
