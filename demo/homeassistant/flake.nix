{
  description = "Home Assistant example for Self Host Blocks";

  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs@{ self, selfhostblocks, sops-nix }:
    let
      system = "x86_64-linux";
      nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;
      nixosSystem' = import "${nixpkgs'}/nixos/lib/eval-config.nix";

      basic = { config, ...  }: {
        imports = [
          ./configuration.nix
          selfhostblocks.nixosModules.x86_64-linux.default
          sops-nix.nixosModules.default
        ];

        sops.defaultSopsFile = ./secrets.yaml;

        shb.home-assistant = {
          enable = true;
          domain = "example.com";
          subdomain = "ha";
          config = {
            name = "SHB Home Assistant";
            country.source = config.shb.sops.secret."home-assistant/country".result.path;
            latitude.source = config.shb.sops.secret."home-assistant/latitude".result.path;
            longitude.source = config.shb.sops.secret."home-assistant/longitude".result.path;
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
        shb.sops.secret."home-assistant/latitude".request = {
          mode = "0440";
          owner = "hass";
          group = "hass";
          restartUnits = [ "home-assistant.service" ];
        };
        shb.sops.secret."home-assistant/longitude".request = {
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

        nixpkgs.config.permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];
      };

      ldap = { config, ...  }: {
        shb.lldap = {
          enable = true;
          domain = "example.com";
          subdomain = "ldap";
          ldapPort = 3890;
          webUIListenPort = 17170;
          dcdomain = "dc=example,dc=com";
          ldapUserPassword.result = config.shb.sops.secret."lldap/user_password".result;
          jwtSecret.result = config.shb.sops.secret."lldap/jwt_secret".result;
        };
        shb.sops.secret."lldap/user_password".request = config.shb.lldap.ldapUserPassword.request;
        shb.sops.secret."lldap/jwt_secret".request = config.shb.lldap.jwtSecret.request;

        shb.home-assistant.ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.lldap.webUIListenPort;
          userGroup = "homeassistant_user";
        };
      };

      sopsConfig = {
        sops.age.keyFile = "/etc/sops/my_key";
        environment.etc."sops/my_key".source = ./keys.txt;
      };
    in
      {
        nixosConfigurations = {
          basic = nixosSystem' {
            system = "x86_64-linux";
            modules = [
              basic
              sopsConfig
            ];
          };

          ldap = nixosSystem' {
            system = "x86_64-linux";
            modules = [
              basic
              ldap
              sopsConfig
            ];
          };
        };

        colmena = {
          meta = {
            nixpkgs = import nixpkgs' {
              system = "x86_64-linux";
            };
            specialArgs = inputs;
          };

          basic = { config, ... }: {
            imports = [
              basic
            ];

            # Used by colmena to know which target host to deploy to.
            deployment = {
              targetHost = "example";
              targetUser = "nixos";
              targetPort = 2222;
            };
          };

          ldap = { config, ... }: {
            imports = [
              basic
              ldap
            ];

            # Used by colmena to know which target host to deploy to.
            deployment = {
              targetHost = "example";
              targetUser = "nixos";
              targetPort = 2222;
            };
          };
        };
      };
}
