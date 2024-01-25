{
  description = "Home Assistant example for Self Host Blocks";

  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = inputs@{ self, selfhostblocks, ... }:
    let
      basic = { config, ...  }: {
        imports = [
          ./configuration.nix
          selfhostblocks.inputs.sops-nix.nixosModules.default
          selfhostblocks.nixosModules.x86_64-linux.default
        ];

        shb.home-assistant = {
          enable = true;
          domain = "example.com";
          subdomain = "ha";
          sopsFile = ./secrets.yaml;
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
          basic = selfhostblocks.inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              basic
              sopsConfig
            ];
          };

          ldap = selfhostblocks.inputs.nixpkgs.lib.nixosSystem {
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
            nixpkgs = import selfhostblocks.inputs.nixpkgs {
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
