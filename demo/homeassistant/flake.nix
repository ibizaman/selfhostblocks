{
  description = "Home Assistant example for Self Host Blocks";

  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs@{ self, selfhostblocks, sops-nix }:
    let
      system = "x86_64-linux";
      originPkgs = selfhostblocks.inputs.nixpkgs;

      nixpkgs' = originPkgs.legacyPackages.${system}.applyPatches {
        name = "nixpkgs-patched";
        src = originPkgs;
        patches = selfhostblocks.patches.${system};
      };
      nixosSystem' = import "${nixpkgs'}/nixos/lib/eval-config.nix";

      basic = { config, ...  }: {
        imports = [
          ./configuration.nix
          selfhostblocks.nixosModules.x86_64-linux.default
          sops-nix.nixosModules.default
        ];

        shb.home-assistant = {
          enable = true;
          domain = "example.com";
          subdomain = "ha";
          config = {
            name = "SHB Home Assistant";
            country.source = config.sops.secrets."home-assistant/country".path;
            latitude.source = config.sops.secrets."home-assistant/latitude".path;
            longitude.source = config.sops.secrets."home-assistant/longitude".path;
            time_zone.source = config.sops.secrets."home-assistant/time_zone".path;
            unit_system = "metric";
          };
        };
        sops.secrets."home-assistant/country" = {
          sopsFile = ./secrets.yaml;
          mode = "0440";
          owner = "hass";
          group = "hass";
          restartUnits = [ "home-assistant.service" ];
        };
        sops.secrets."home-assistant/latitude" = {
          sopsFile = ./secrets.yaml;
          mode = "0440";
          owner = "hass";
          group = "hass";
          restartUnits = [ "home-assistant.service" ];
        };
        sops.secrets."home-assistant/longitude" = {
          sopsFile = ./secrets.yaml;
          mode = "0440";
          owner = "hass";
          group = "hass";
          restartUnits = [ "home-assistant.service" ];
        };
        sops.secrets."home-assistant/time_zone" = {
          sopsFile = ./secrets.yaml;
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
        shb.ldap = {
          enable = true;
          domain = "example.com";
          subdomain = "ldap";
          ldapPort = 3890;
          webUIListenPort = 17170;
          dcdomain = "dc=example,dc=com";
          ldapUserPasswordFile = config.sops.secrets."lldap/user_password".path;
          jwtSecretFile = config.sops.secrets."lldap/jwt_secret".path;
        };
        sops.secrets."lldap/user_password" = {
          sopsFile = ./secrets.yaml;
          mode = "0440";
          owner = "lldap";
          group = "lldap";
          restartUnits = [ "lldap.service" ];
        };
        sops.secrets."lldap/jwt_secret" = {
          sopsFile = ./secrets.yaml;
          mode = "0440";
          owner = "lldap";
          group = "lldap";
          restartUnits = [ "lldap.service" ];
        };

        shb.home-assistant.ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.ldap.webUIListenPort;
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
