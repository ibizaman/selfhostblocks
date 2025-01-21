# LDAP Group Contract {#contract-ldapgroup}

This NixOS contract represents an LDAP group
that must be created.

It is a contract between a service that needs an LDAP group
and a service that can provide such a group.

## Contract Reference {#contract-ldapgroup-options}

These are all the options that are expected to exist for this contract to be respected.

```{=include=} options
id-prefix: contracts-ldapgroup-options-
list-id: selfhostblocks-options
source: @OPTIONS_JSON@
```

## Usage {#contract-ldapgroup-usage}

What this contract defines is, from the user perspective - that is _you_ - an implementation detail
but you can know it simply defines the LDAP group name.

A NixOS module that needs a LDAP group using this contract will provide a `ldapgroup` option or similarly named.
Such a service is a `requester` providing a `request` for a module `provider` of this contract. 

Here is an example module defining such a `ldapgroup` option:

```nix
{
  options = {
    myservice.ldapgroup = mkOption {
      type = contracts.ldapgroup.request;
    };
  };
};
```

Now, on the other side we have a service that uses this `ldapgroup` option and actually creates the LDAP group.
This service is a `provider` of this contract and will provide a `result` option containing the name of the group.

```nix
{
  options = {
    ldap.groups = lib.mkOption {
      description = "LDAP Groups to manage declaratively.";
      default = {};
      example = lib.literalExpression ''
      {
        family = {};
      }
      '';
      type = attrsOf (submodule ({ name, config, ... }: {
        options = contracts.ldapgroup.mkProvider {
          settings = mkOption {
            description = ''
              Settings specific to the LLDAP provider.

              By default it is the same as the field name.
            '';
            default = {
              inherit name;
            };

            type = submodule {
              options = {
                name = mkOption {
                  description = "Name of the LDAP group";
                  type = str;
                  default = name;
                };
              };
            };
          };

          resultCfg = {
            name = config.settings.name;
            nameText = name;
          };
        };
      }));
    };
  };
};
```

Then, to actually backup the `myservice` service,
one would need to link the requester to the provider with:

```nix
# requester -> provider
ldapgroupservice.groups.myservice = {
  request = config.myservice.ldapgroup.request;
};
# provider -> requester
myservice.ldapgroup.result = config.ldapgroupservice.groups.myservice.result;
```

By default, the name of the LDAP group will be the same as the field name under the `groups` option. Here, `"myservice"`.

Usually, a service will require two LDAP groups to work properly,
one for users and another one for admin users.
In this case, the linking them together will look like so:

```nix
# requester -> provider
ldapgroupservice.groups = {
  myservice_user.request  = config.myservice.ldap.userGroup.request;
  myservice_admin.request = config.myservice.ldap.adminGroup.request;
};
# provider -> requester
myservice.ldap = {
  userGroup.result  = config.ldapgroupservice.groups.myservice_user.result;
  adminGroup.result = config.ldapgroupservice.groups.myservice_admin.result;
};
```

## Providers of the Database Backup Contract {#contract-ldapgroup-providers}

- [LDAP block](blocks-ldap.html).

## Requester Blocks and Services {#contract-ldapgroup-requesters}

- [Nextcloud service](services-nextcloud.html#services-nextcloud-contract-ldapgroup).
