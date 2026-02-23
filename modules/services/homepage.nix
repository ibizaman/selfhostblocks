{
  config,
  lib,
  shb,
  ...
}:
let
  cfg = config.shb.homepage;

  inherit (lib) types;
in
{
  imports = [
    ../../lib/module.nix

    ../blocks/lldap.nix
    ../blocks/nginx.nix
  ];

  options.shb.homepage = {
    enable = lib.mkEnableOption "the SHB homepage service";

    subdomain = lib.mkOption {
      type = types.str;
      description = ''
        Subdomain under which homepage will be served.

        ```
        <subdomain>.<domain>
        ```
      '';
      example = "homepage";
    };

    domain = lib.mkOption {
      description = ''
        Domain under which homepage is served.

        ```
        <subdomain>.<domain>
        ```
      '';
      type = types.str;
      example = "domain.com";
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = types.nullOr shb.contracts.ssl.certs;
      default = null;
    };

    servicesGroups = lib.mkOption {
      description = "Group of services that should be showed on the dashboard.";
      default = { };
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              name = lib.mkOption {
                type = types.str;
                description = "Display name of the group. Defaults to the attr name.";
                default = name;
              };
              sortOrder = lib.mkOption {
                description = ''
                  Order in which groups will be shown.

                  The rules are:

                    - Lowest number is shown first.
                    - Two groups having the same number are shown in a consistent (same across multiple deploys) but undefined order.
                    - Default is null which means at the end.
                '';
                type = types.nullOr types.int;
                default = null;
              };
              services = lib.mkOption {
                description = "Services that should be showed in the group on the dashboard.";
                default = { };
                type = types.attrsOf (
                  types.submodule (
                    { name, ... }:
                    {
                      options = {
                        name = lib.mkOption {
                          type = types.str;
                          description = "Display name of the service. Defaults to the attr name.";
                          default = name;
                        };
                        sortOrder = lib.mkOption {
                          type = types.nullOr types.int;
                          description = ''
                            Order in which groups will be shown.

                            The rules are:

                              - Lowest number is shown first.
                              - Two groups having the same number are shown in a consistent (same across multiple deploys) but undefined order.
                              - Default is null which means at the end.
                          '';
                          default = null;
                        };
                        dashboard = lib.mkOption {
                          description = ''
                            Provider of the dashboard contract.

                            By default:

                              - The `serviceName` option comes from the attr name.
                              - The `icon` option comes from applying `toLower` on the attr name.
                              - The `siteMonitor` option is set only if `internalUrl` is set.
                          '';
                          type = types.submodule {
                            options = shb.contracts.dashboard.mkProvider {
                              resultCfg = { };
                            };
                          };
                        };
                        apiKey = lib.mkOption {
                          description = ''
                            API key used to access the service.

                            This can be used to get data from the service.
                          '';
                          default = null;
                          type = types.nullOr (
                            lib.types.submodule {
                              options = shb.contracts.secret.mkRequester {
                                owner = "root";
                                restartUnits = [ "homepage-dashboard.service" ];
                              };
                            }
                          );
                        };
                        settings = lib.mkOption {
                          description = ''
                            Extra options to pass to the homepage service.

                            Check https://gethomepage.dev/configs/services/#icons
                            if the default icon is not correct.

                            And check https://gethomepage.dev/widgets
                            if the default widget type is not correct.
                          '';
                          default = { };
                          type = types.attrsOf types.anything;
                          example = lib.literalExpression ''
                            {
                              icon = "si-homeassistant";
                              widget.type = "firefly";
                              widget.custom = [
                                {
                                  template = "{{ states('sensor.total_power', with_unit=True, rounded=True) }}";
                                  label = "energy now";
                                }
                                {
                                  state = "sensor.total_power_today";
                                  label = "energy today";
                                }
                              ];
                            }
                          '';
                        };
                      };
                    }
                  )
                );
              };
            };
          }
        )
      );
    };

    ldap = lib.mkOption {
      description = ''
        Setup LDAP integration.
      '';
      default = { };
      type = types.submodule {
        options = {
          userGroup = lib.mkOption {
            type = types.str;
            description = "Group users must belong to be able to login.";
            default = "homepage_user";
          };
        };
      };
    };

    sso = lib.mkOption {
      description = ''
        Setup SSO integration.
      '';
      default = { };
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption "SSO integration.";

          authEndpoint = lib.mkOption {
            type = lib.types.str;
            description = "Endpoint to the SSO provider.";
            example = "https://authelia.example.com";
          };

          authorization_policy = lib.mkOption {
            type = types.enum [
              "one_factor"
              "two_factor"
            ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;

      allowedHosts = "${cfg.subdomain}.${cfg.domain}";

      settings = {
        baseUrl = "https://${cfg.subdomain}.${cfg.domain}";
        startUrl = "https://${cfg.subdomain}.${cfg.domain}";
        disableUpdateCheck = true;
      };

      bookmarks = [ ];

      services = shb.homepage.asServiceGroup cfg.servicesGroups;

      widgets = [ ];
    };

    systemd.services.homepage-dashboard.serviceConfig =
      let
        keys = shb.homepage.allKeys cfg.servicesGroups;
      in
      {
        # LoadCredential = [
        #   "Media_Jellyfin:/path"
        # ];
        LoadCredential = lib.mapAttrsToList (name: path: "${name}:${path}") keys;
        # Environment = [
        #   "HOMEPAGE_FILE_Media_Jellyfin=%d/Media_Jellyfin"
        # ];
        Environment = lib.mapAttrsToList (name: path: "HOMEPAGE_FILE_${name}=%d/${name}") keys;
      };

    # This should be using a contract instead of setting the option directly.
    shb.lldap = lib.mkIf config.shb.lldap.enable {
      ensureGroups = {
        ${cfg.ldap.userGroup} = { };
      };
    };

    shb.nginx.vhosts = [
      (
        {
          inherit (cfg) subdomain domain ssl;

          upstream = "http://127.0.0.1:${toString config.services.homepage-dashboard.listenPort}/";
          extraConfig = ''
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
          '';
          autheliaRules = lib.optionals (cfg.sso.enable) [
            {
              domain = "${cfg.subdomain}.${cfg.domain}";
              policy = cfg.sso.authorization_policy;
              subject = [ "group:${cfg.ldap.userGroup}" ];
            }
          ];
        }
        // lib.optionalAttrs cfg.sso.enable {
          inherit (cfg.sso) authEndpoint;
        }
      )
    ];
  };
}
