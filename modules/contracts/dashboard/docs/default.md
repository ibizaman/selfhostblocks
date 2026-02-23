# Dashboard Contract {#contract-dashboard}

This NixOS contract is used for user-facing services
that want to be displayed on a dashboard.

It is a contract between a service that can be accessed through an URL
and a service that wants to show a list of those services.

## Providers {#contract-dashboard-providers}

The providers of this contract in SHB are:

<!-- Somehow generate this list -->

- The homepage service under its [shb.homepage.servicesGroups.<name>.services.<name>.dashboard](#services-homepage-options-shb.homepage.servicesGroups._name_.services._name_.dashboard) option.

## Usage {#contracts-dashboard-usage}

A service that can be shown on a dashboard will provide a `dashboard` option.

Here is an example module defining such a requester option for this dashboard contract:

```nix
{
  options = {
    myservice.dashboard = lib.mkOption {
      description = ''
        Dashboard contract consumer
      '';
      default = { };
      type = lib.types.submodule {
        options = shb.contracts.dashboard.mkRequester {
          externalUrl = "https://${config.myservice.subdomain}.${config.myservice.domain}";
          internalUrl = "http://127.0.0.1:${config.myservice.port}";
        };
      };
    };
  };
};
```

Then, plug both consumer and provider together in the `config`:

```nix
{
  config = {
    <provider-module> = {
      dashboard.request = config.myservice.dashboard.request;
    };
  };
}
```

And that's it for the contract part.
For more specific details on each provider, go to their respective manual pages.

## Contract Reference {#contract-dashboard-options}

These are all the options that are expected to exist for this contract to be respected.

```{=include=} options
id-prefix: contracts-dashboard-options-
list-id: selfhostblocks-options
source: @OPTIONS_JSON@
```
