# Home-Assistant Service {#services-home-assistant}

Defined in [`/modules/services/home-assistant.nix`](@REPO@/modules/services/home-assistant.nix).

This NixOS module is a service that sets up a [Home-Assistant](https://www.home-assistant.io/) instance.

Compared to the stock module from nixpkgs,
this one sets up, in a fully declarative manner
LDAP and SSO integration.

## Features {#services-home-assistant-features}

- Declarative creation of users, admin or not.
- Also declarative [LDAP](#services-home-assistant-options-shb.home-assistant.ldap) Configuration. [Manual](#services-home-assistant-usage-ldap).
- Access through [subdomain](#services-home-assistant-options-shb.home-assistant.subdomain) using reverse proxy. [Manual](#services-home-assistant-usage-configuration).
- Access through [HTTPS](#services-home-assistant-options-shb.home-assistant.ssl) using reverse proxy. [Manual](#services-home-assistant-usage-configuration).
- [Backup](#services-home-assistant-options-shb.home-assistant.backup) through the [backup block](./blocks-backup.html). [Manual](#services-home-assistant-usage-backup).
- Integration with the [dashboard contract](contracts-dashboard.html) for displaying user facing application in a dashboard. [Manual](#services-home-assistant-usage-applicationdashboard)

- Not yet: declarative SSO.

## Usage {#services-home-assistant-usage}

### Initial Configuration {#services-home-assistant-usage-configuration}

The following snippet enables Home-Assistant and makes it available under the `ha.example.com` endpoint.

```nix
shb.home-assistant = {
  enable = true;
  subdomain = "ha";
  domain = "example.com";

  config = {
    name = "SelfHostBlocks - Home Assistant";
    country.source = config.shb.sops.secret."home-assistant/country".result.path;
    latitude.source = config.shb.sops.secret."home-assistant/latitude_home".result.path;
    longitude.source = config.shb.sops.secret."home-assistant/longitude_home".result.path;
    time_zone.source = config.shb.sops.secret."home-assistant/time_zone".result.path;
    unit_system = "metric";
  };
};

shb.sops.secret."home-assistant/country".request = {
  mode = "0440";
  owner = "hass";
  group = "hass";
  restartUnits = [ "home-assistant.service" ];
};
shb.sops.secret."home-assistant/latitude_home".request = {
  mode = "0440";
  owner = "hass";
  group = "hass";
  restartUnits = [ "home-assistant.service" ];
};
shb.sops.secret."home-assistant/longitude_home".request = {
  mode = "0440";
  owner = "hass";
  group = "hass";
  restartUnits = [ "home-assistant.service" ];
};
shb.sops.secret."home-assistant/time_zone".request = {
  mode = "0440";
  owner = "hass";
  group = "hass";
  restartUnits = [ "home-assistant.service" ];
};
```

This assumes secrets are setup with SOPS
as mentioned in [the secrets setup section](usage.html#usage-secrets) of the manual.

Any item in the `config` can be passed a secret, which means it will not appear
in the `/nix/store` and instead be added to the config file out of band, here using sops.
To do that, append `.source` to the settings name and give it the path to the secret.

I advise using secrets to set personally identifiable information,
like shown in the snippet. Especially if you share your repository publicly.

### Home-Assistant through HTTPS {#services-home-assistant-usage-https}

:::: {.note}
We will build upon the [Initial Configuration](#services-home-assistant-usage-configuration) section,
so please follow that first.
::::

If the `shb.ssl` block is used (see [manual](blocks-ssl.html#usage) on how to set it up),
the instance will be reachable at `https://ha.example.com`.

Here is an example with Let's Encrypt certificates, validated using the HTTP method.
First, set the global configuration for your domain:

```nix
shb.certs.certs.letsencrypt."example.com" = {
  domain = "example.com";
  group = "nginx";
  reloadServices = [ "nginx.service" ];
  adminEmail = "myemail@mydomain.com";
};
```

Then you can tell Home-Assistant to use those certificates.

```nix
shb.certs.certs.letsencrypt."example.com".extraDomains = [ "ha.example.com" ];

shb.home-assistant = {
  ssl = config.shb.certs.certs.letsencrypt."example.com";
};
```

### With LDAP Support {#services-home-assistant-usage-ldap}

:::: {.note}
We will build upon the [HTTPS](#services-home-assistant-usage-https) section,
so please follow that first.
::::

We will use the [LLDAP block][] provided by Self Host Blocks.
Assuming it [has been set already][LLDAP block setup], add the following configuration:

[LLDAP block]: blocks-lldap.html
[LLDAP block setup]: blocks-lldap.html#blocks-lldap-global-setup

```nix
shb.home-assistant.ldap
  enable = true;
  host = "127.0.0.1";
  port = config.shb.lldap.webUIListenPort;
  userGroup = "homeassistant_user";
};
```

And that's it.
Now, go to the LDAP server at `http://ldap.example.com`,
create the `home-assistant_user` group,
create a user and add it to one or both groups.
When that's done, go back to the Home-Assistant server at
`http://home-assistant.example.com` and login with that user.

### With SSO Support {#services-home-assistant-usage-sso}

:::: {.warning}
This is not implemented yet. Any contributions ([issue #12](https://github.com/ibizaman/selfhostblocks/issues/12)) are welcomed!
::::

### Backup {#services-home-assistant-usage-backup}

Backing up Home-Assistant using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."home-assistant" = {
  request = config.shb.home-assistant.backup;
  settings = {
    enable = true;
  };
};
```

The name `"home-assistant"` in the `instances` can be anything.
The `config.shb.home-assistant.backup` option provides what directories to backup.
You can define any number of Restic instances to backup Home-Assistant multiple times.

You will then need to configure more options like the `repository`,
as explained in the [restic](blocks-restic.html) documentation.

### Application Dashboard {#services-home-assistant-usage-applicationdashboard}

Integration with the [dashboard contract](contracts-dashboard.html) is provided
by the [dashboard option](#services-home-assistant-options-shb.home-assistant.dashboard).

For example using the [Homepage](services-homepage.html) service:

```nix
{
  shb.homepage.servicesGroups.Home.services.HomeAssistant = {
    sortOrder = 1;
    dashboard.request = config.shb.home-assistant.dashboard.request;
    settings.icon = "si-homeassistant";
  };
}
```

The icon needs to be set manually otherwise it is not displayed correctly.

An API key can be set to show extra info:

```nix
{
  shb.homepage.servicesGroups.Home.services.HomeAssistant = {
    apiKey.result = config.shb.sops.secret."home-assistant/homepageApiKey".result;
  };

  shb.sops.secret."home-assistant/homepageApiKey".request =
    config.shb.homepage.servicesGroups.Home.services.HomeAssistant.apiKey.request;
}
```

Custom widgets can be set using Home Assistant templating:

```nix
{
  shb.homepage.servicesGroups.Home.services.HomeAssistant = {
    settings.widget.custom = [
      {
        template = "{{ states('sensor.power_consumption_power_consumption', with_unit=True, rounded=True) }}";
        label = "energy now";
      }
      {
        state = "sensor.power_consumption_daily_power_consumption";
        label = "energy today";
      }
    ];
  };
}
```

### Extra Components {#services-home-assistant-usage-extra-components}

Packaged components can be found in the documentation of the corresponding option
[services.home-assistant.extraComponents](https://search.nixos.org/options?channel=25.05&show=services.home-assistant.extraComponents&from=0&size=50&sort=relevance&type=packages&query=services.home-assistant.extraComponents)

[services.home-assistant-extraComponents]: https://search.nixos.org/options?channel=25.05&show=services.home-assistant.extraComponents&from=0&size=50&sort=relevance&type=packages&query=services.home-assistant.extraComponents

When you find an interesting one add it to the option:

```bash
services.home-assistant.extraComponents = [
  "backup"
  "bluetooth"
  "esphome"

  "assist_pipeline"
  "conversation"
  "piper"
  "wake_word"
  "whisper"
  "wyoming"
];
```

Some components are not available as extra components, but need to be added as cusotm components.
If the component is not packaged, you'll need to use a [custom component](#services-home-assistant-usage-custom-components).

### Custom Components {#services-home-assistant-usage-custom-components}

:::: {.note}
I'm still confused for why is there a difference between custom components and extra components.
::::

Available custom components can be found by searching packages for [home-assistant-custom-components][].

[home-assistant-custom-components]: https://search.nixos.org/packages?channel=25.05&from=0&size=50&sort=alpha_asc&type=packages&query=home-assistant-custom-components

Add them like so:

```nix
services.home-assistant.customComponents = with pkgs.home-assistant-custom-components; [
  adaptive_lighting
];
```

To add a not packaged component, you can get inspiration from existing [packaged components.
To help you package a custom component [nixpkgs code][component-packages.nix] to package it
using the `pkgs.buildHomeAssistantComponent` function.

[component-packages.nix]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/home-assistant/component-packages.nix

When done, add it to the same `services.home-assistant.customComponents` option.
Also, don't hesitate to upstream it to nixpkgs.

### Custom Lovelace Modules {#services-home-assistant-usage-custom-lovelace-modules}

To add custom Lovelace UI elements, add them to the `services.home-assistant.customLovelaceModules` option.
Available custom components can be found by searching packages for [home-assistant-custom-lovelace-modules][].

[home-assistant-custom-lovelace-modules]: https://search.nixos.org/packages?channel=25.05&from=0&size=50&sort=alpha_asc&type=packages&query=home-assistant-custom-lovelace-modules

```nix
services.home-assistant.customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
  mini-graph-card
  mini-media-player
  hourly-weather
  weather-card
];
```

### Extra Packages {#services-home-assistant-usage-extra-packages}

This is really only needed if by mischance, one of the components added earlier
fail because of a missing Python3 package when the home-assistant systemd service is started.
Usually, the required module will be shown in the traceback.
To know to which nixpkgs package this Python3 package correspond,
search for a package in the [python3XXPackages set][].

[python3XXPackages set]: https://search.nixos.org/packages?channel=25.05&from=0&size=50&buckets=%7B%22package_attr_set%22%3A%5B%22python313Packages%22%5D%2C%22package_license_set%22%3A%5B%5D%2C%22package_maintainers_set%22%3A%5B%5D%2C%22package_teams_set%22%3A%5B%5D%2C%22package_platforms%22%3A%5B%5D%7D&sort=alpha_asc&type=packages&query=grpcio

```nix
services.home-assistant.extraPackages = python3Packages: with python3Packages; [
  grpcio
];
```

### Extra Groups {#services-home-assistant-usage-extra-groups}

Some components need access to hardware components which mean the home-assistant user
`hass` must be added to some Unix group.
For example, the `hass` user must be added to the `dialout` group for the Sonoff component.

There's no systematic way to know this apart reading the logs when a
home-assistant component fails to start.

```nix
users.users.hass.extraGroups = [ "dialout" ];
```

### Voice {#services-home-assistant-usage-voice}

Text to speech (TTS) and speech to text (STT) can be added with the
stock nixpkgs options. The most performance hungry one is STT.
If you don't have a good CPU or better a GPU, you won't be able
to use medium to big models. From my own experience using a low-end
CPU, voice is pretty much unusable like that, even with mini models.

Here is the configuration I use on a low-end CPU:

```nix
shb.home-assistant.voice.text-to-speech = {
  "fr" = {
    enable = true;
    voice = "fr-siwis-medium";
    uri = "tcp://0.0.0.0:10200";
    speaker = 0;
  };
  "en" = {
    enable = true;
    voice = "en_GB-alba-medium";
    uri = "tcp://0.0.0.0:10201";
    speaker = 0;
  };
};
shb.home-assistant.voice.speech-to-text = {
  "tiny-fr" = {
    enable = true;
    model = "base-int8";
    language = "fr";
    uri = "tcp://0.0.0.0:10300";
    device = "cpu";
  };
  "tiny-en" = {
    enable = true;
    model = "base-int8";
    language = "en";
    uri = "tcp://0.0.0.0:10301";
    device = "cpu";
  };
};
systemd.services.wyoming-faster-whisper-tiny-en.environment."HF_HUB_CACHE" = "/tmp";
systemd.services.wyoming-faster-whisper-tiny-fr.environment."HF_HUB_CACHE" = "/tmp";
shb.home-assistant.voice.wakeword = {
  enable = true;
  uri = "tcp://127.0.0.1:10400";
  preloadModels = [
    "ok_nabu"
  ];
};
```

### Music Assistant {#services-home-assistant-usage-music-assistant}

To add Music Assistant under the `ma.example.com` domain
with two factor SSO authentication, use the following configuration.
This assumes the [SSL][] and [SSO][] blocks are configured.

[SSL]: blocks-ssl.html
[SSO]: blocks-sso.html

```nix
services.music-assistant = {
  enable = true;
  providers = [
    "airplay"
    "hass"
    "hass_players"
    "jellyfin"
    "radiobrowser"
    "sonos"
    "spotify"
  ];
};

shb.nginx.vhosts = [
  {
    subdomain = "ma";
    domain = "example.com";
    ssl = config.shb.certs.certs.letsencrypt.${domain};
    authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    upstream = "http://127.0.0.1:8095";
    autheliaRules = [{
      domain = "ma.${domain}";
      policy = "two_factor";
      subject = ["group:music-assistant_user"];
    }];
  }
];
```

## Debug {#services-home-assistant-debug}

In case of an issue, check the logs for systemd service `home-assistant.service`.

Enable verbose logging by setting the `shb.home-assistant.debug` boolean to `true`.

Access the database with `sudo -u home-assistant psql`.

## Options Reference {#services-home-assistant-options}

```{=include=} options
id-prefix: services-home-assistant-options-
list-id: selfhostblocks-service-home-assistant-options
source: @OPTIONS_JSON@
```
