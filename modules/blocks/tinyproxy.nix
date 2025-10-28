# Inspired from https://github.com/NixOS/nixpkgs/pull/231152 but made it so we can have multiple instances.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.shb.tinyproxy;

  mkValueStringTinyproxy =
    with lib;
    v:
    if true == v then
      "yes"
    else if false == v then
      "no"
    else
      generators.mkValueStringDefault { } v;

  mkKeyValueTinyproxy =
    {
      mkValueString ? mkValueStringDefault { },
    }:
    sep: k: v:
    if null == v then "" else "${lib.strings.escape [ sep ] k}${sep}${mkValueString v}";

  settingsFormat = (
    pkgs.formats.keyValue {
      mkKeyValue = mkKeyValueTinyproxy {
        mkValueString = mkValueStringTinyproxy;
      } " ";
      listsAsDuplicateKeys = true;
    }
  );

  configFile = name: cfg: settingsFormat.generate "tinyproxy-${name}.conf" cfg.settings;
in
{
  options =
    let
      instanceOption = types.submodule {
        options = {
          enable = mkEnableOption "Tinyproxy daemon";

          package = mkPackageOption pkgs "tinyproxy" { };

          dynamicBindFile = mkOption {
            description = ''
              File holding the IP to bind to.
            '';
            default = "";
          };

          settings = mkOption {
            description = ''
              Configuration for [tinyproxy](https://tinyproxy.github.io/).
            '';
            default = { };
            example = literalExpression ''
              {
                          Port 8888;
                          Listen 127.0.0.1;
                          Timeout 600;
                          Allow 127.0.0.1;
                          Anonymous = ['"Host"' '"Authorization"'];
                          ReversePath = '"/example/" "http://www.example.com/"';
                          }'';
            type = types.submodule (
              { name, ... }:
              {
                freeformType = settingsFormat.type;
                options = {
                  Listen = mkOption {
                    type = types.str;
                    default = "127.0.0.1";
                    description = ''
                      Specify which address to listen to.
                    '';
                  };
                  Port = mkOption {
                    type = types.int;
                    default = 8888;
                    description = ''
                      Specify which port to listen to.
                    '';
                  };
                  Anonymous = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = ''
                      If an `Anonymous` keyword is present, then anonymous proxying is enabled. The
                      headers listed with `Anonymous` are allowed through, while all others are denied.
                      If no Anonymous keyword is present, then all headers are allowed through. You must
                      include quotes around the headers.
                    '';
                  };
                  Filter = mkOption {
                    type = types.nullOr types.path;
                    default = null;
                    description = ''
                      Tinyproxy supports filtering of web sites based on URLs or domains. This option
                      specifies the location of the file containing the filter rules, one rule per line.
                    '';
                  };
                };
              }
            );
          };
        };
      };
    in
    {
      shb.tinyproxy = mkOption {
        description = "Tinyproxy instances.";
        default = { };
        type = types.attrsOf instanceOption;
      };
    };

  config = {
    systemd.services =
      let
        instanceConfig =
          name: c:
          mkIf c.enable {
            "tinyproxy-${name}" = {
              description = "TinyProxy daemon - instance ${name}";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                User = "tinyproxy";
                Group = "tinyproxy";
                Type = "simple";
                ExecStart = "${getExe c.package} -d -c /etc/tinyproxy/${name}.conf";
                ExecReload = "${pkgs.coreutils}/bin/kill -SIGHUP $MAINPID";
                KillSignal = "SIGINT";
                TimeoutStopSec = "30s";
                Restart = "on-failure";
                RestartSec = "1s";
                RestartSteps = "3";
                RestartMaxDelaySec = "10s";
                ConfigurationDirectory = "tinyproxy";
              };
              preStart = concatStringsSep "\n" (
                [
                  "cat ${configFile name c} > /etc/tinyproxy/${name}.conf"
                ]
                ++ optionals (c.dynamicBindFile != "") [
                  "echo -n 'Bind ' >> /etc/tinyproxy/${name}.conf"
                  "cat ${c.dynamicBindFile} >> /etc/tinyproxy/${name}.conf"
                ]
              );
            };
          };
      in
      mkMerge (mapAttrsToList instanceConfig cfg);

    users.users.tinyproxy = {
      group = "tinyproxy";
      isSystemUser = true;
    };
    users.groups.tinyproxy = { };
  };

  meta.maintainers = with maintainers; [ tcheronneau ];
}
