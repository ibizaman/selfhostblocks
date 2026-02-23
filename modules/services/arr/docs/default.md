# *Arr Service {#services-arr}

Defined in [`/modules/services/arr.nix`](@REPO@/modules/services/arr.nix).

This NixOS module sets up multiple [Servarr](https://wiki.servarr.com/) services.
## Features {#services-arr-features}

Compared to the stock module from nixpkgs,
this one sets up, in a fully declarative manner
LDAP and SSO integration as well as the API key.

## Usage {#services-arr-usage}

### Initial Configuration {#services-arr-usage-configuration}

The following snippet assumes a few blocks have been setup already:

- the [secrets block](usage.html#usage-secrets) with SOPS,
- the [`shb.ssl` block](blocks-ssl.html#usage),
- the [`shb.lldap` block](blocks-lldap.html#blocks-lldap-global-setup).
- the [`shb.authelia` block](blocks-authelia.html#blocks-sso-global-setup).

```nix
{
  shb.certs.certs.letsencrypt.${domain}.extraDomains = [
    "moviesdl.${domain}"
    "seriesdl.${domain}"
    "subtitlesdl.${domain}"
    "booksdl.${domain}"
    "musicdl.${domain}"
    "indexer.${domain}"
  ];

  shb.arr = {
    radarr = {
      inherit domain;
      enable = true;
      ssl = config.shb.certs.certs.letsencrypt.${domain};
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
    sonarr = {
      inherit domain;
      enable = true;
      ssl = config.shb.certs.certs.letsencrypt."${domain}";
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
    bazarr = {
      inherit domain;
      enable = true;
      ssl = config.shb.certs.certs.letsencrypt."${domain}";
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
    readarr = {
      inherit domain;
      enable = true;
      ssl = config.shb.certs.certs.letsencrypt."${domain}";
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
    lidarr = {
      inherit domain;
      enable = true;
      ssl = config.shb.certs.certs.letsencrypt."${domain}";
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
    jackett = {
      inherit domain;
      enable = true;
      ssl = config.shb.certs.certs.letsencrypt."${domain}";
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
  };
}
```

The user and admin LDAP groups are created automatically.

### API Keys {#services-arr-usage-apikeys}

The API keys for each arr service can be created declaratively.

First, generate one secret for each service with `nix run nixpkgs#openssl -- rand -hex 64`
and store it in your secrets file (for example the SOPS file).

Then, add the API key to each service:

```nix
{
  shb.arr = {
    radarr = {
      settings = {
        ApiKey.source = config.shb.sops.secret."radarr/apikey".result.path;
      };
    };
    sonarr = {
      settings = {
        ApiKey.source = config.shb.sops.secret."sonarr/apikey".result.path;
      };
    };
    bazarr = {
      settings = {
        ApiKey.source = config.shb.sops.secret."bazarr/apikey".result.path;
      };
    };
    readarr = {
      settings = {
        ApiKey.source = config.shb.sops.secret."readarr/apikey".result.path;
      };
    };
    lidarr = {
      settings = {
        ApiKey.source = config.shb.sops.secret."lidarr/apikey".result.path;
      };
    };
    jackett = {
      settings = {
        ApiKey.source = config.shb.sops.secret."jackett/apikey".result.path;
      };
    };
  };

  shb.sops.secret."radarr/apikey".request = {
    mode = "0440";
    owner = "radarr";
    group = "radarr";
    restartUnits = [ "radarr.service" ];
  };
  shb.sops.secret."sonarr/apikey".request = {
    mode = "0440";
    owner = "sonarr";
    group = "sonarr";
    restartUnits = [ "sonarr.service" ];
  };
  shb.sops.secret."bazarr/apikey".request = {
    mode = "0440";
    owner = "bazarr";
    group = "bazarr";
    restartUnits = [ "bazarr.service" ];
  };
  shb.sops.secret."readarr/apikey".request = {
    mode = "0440";
    owner = "readarr";
    group = "readarr";
    restartUnits = [ "readarr.service" ];
  };
  shb.sops.secret."lidarr/apikey".request = {
    mode = "0440";
    owner = "lidarr";
    group = "lidarr";
    restartUnits = [ "lidarr.service" ];
  };
  shb.sops.secret."jackett/apikey".request = {
    mode = "0440";
    owner = "jackett";
    group = "jackett";
    restartUnits = [ "jackett.service" ];
  };
}
```

### Application Dashboard {#services-arr-usage-applicationdashboard}

Integration with the [dashboard contract](contracts-dashboard.html) is provided
by the various dashboard options.

For example using the [Homepage](services-homepage.html) service:

```nix
{
  shb.homepage.servicesGroups.Media.services.Radarr = {
    sortOrder = 10;
    dashboard.request = config.shb.arr.radarr.dashboard.request;
    apiKey.result = config.shb.sops.secret."radarr/homepageApiKey".result;
  };
  shb.sops.secret."radarr/homepageApiKey" = {
    settings.key = "radarr/apikey";
    request = config.shb.homepage.servicesGroups.Media.services.Radarr.apiKey.request;
  };
  shb.homepage.servicesGroups.Media.services.Sonarr = {
    sortOrder = 11;
    dashboard.request = config.shb.arr.sonarr.dashboard.request;
    apiKey.result = config.shb.sops.secret."sonarr/homepageApiKey".result;
  };
  shb.sops.secret."sonarr/homepageApiKey" = {
    settings.key = "sonarr/apikey";
    request = config.shb.homepage.servicesGroups.Media.services.Sonarr.apiKey.request;
  };
  shb.homepage.servicesGroups.Media.services.Bazarr = {
    sortOrder = 12;
    dashboard.request = config.shb.arr.bazarr.dashboard.request;
    apiKey.result = config.shb.sops.secret."bazarr/homepageApiKey".result;
  };
  shb.sops.secret."bazarr/homepageApiKey" = {
    settings.key = "bazarr/apikey";
    request = config.shb.homepage.servicesGroups.Media.services.Bazarr.apiKey.request;
  };
  shb.homepage.servicesGroups.Media.services.Readarr = {
    sortOrder = 13;
    dashboard.request = config.shb.arr.readarr.dashboard.request;
    apiKey.result = config.shb.sops.secret."readarr/homepageApiKey".result;
  };
  shb.sops.secret."readarr/homepageApiKey" = {
    settings.key = "readarr/apikey";
    request = config.shb.homepage.servicesGroups.Media.services.Readarr.apiKey.request;
  };
  shb.homepage.servicesGroups.Media.services.Lidarr = {
    sortOrder = 14;
    dashboard.request = config.shb.arr.lidarr.dashboard.request;
    apiKey.result = config.shb.sops.secret."lidarr/homepageApiKey".result;
  };
  shb.sops.secret."lidarr/homepageApiKey" = {
    settings.key = "lidarr/apikey";
    request = config.shb.homepage.servicesGroups.Media.services.Lidarr.apiKey.request;
  };
  shb.homepage.servicesGroups.Media.services.Jackett = {
    sortOrder = 15;
    dashboard.request = config.shb.arr.jackett.dashboard.request;
    apiKey.result = config.shb.sops.secret."jackett/homepageApiKey".result;
  };
  shb.sops.secret."jackett/homepageApiKey" = {
    settings.key = "jackett/apikey";
    request = config.shb.homepage.servicesGroups.Media.services.Jackett.apiKey.request;
  };
}
```

This example reuses the API keys generated declaratively from the previous section.

### Jackett Proxy {#services-arr-usage-jackett-proxy}

The Jackett service can be made to use a proxy with:

```nix
{
  shb.arr.jackett = {
    settings = {
      ProxyType = "0";
      ProxyUrl = "127.0.0.1:1234";
    };
  };
};
```

## Options Reference {#services-arr-options}

```{=include=} options
id-prefix: services-arr-options-
list-id: selfhostblocks-service-arr-options
source: @OPTIONS_JSON@
```
