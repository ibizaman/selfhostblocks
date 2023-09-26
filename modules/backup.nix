{ config, pkgs, lib, ... }:

let
  cfg = config.shb.backup;

  instanceOptions = {
    backend = lib.mkOption {
      description = "What program to use to make the backups.";
      type = lib.types.enum [ "borgmatic" "restic" ];
      example = "borgmatic";
    };

    keySopsFile = lib.mkOption {
      description = "Sops file that holds this instance's Borgmatic repository key and passphrase.";
      type = lib.types.path;
      example = "secrets/backup.yaml";
    };

    sourceDirectories = lib.mkOption {
      description = "Borgmatic source directories.";
      type = lib.types.nonEmptyListOf lib.types.str;
    };

    excludePatterns = lib.mkOption {
      description = "Borgmatic exclude patterns.";
      type = lib.types.listOf lib.types.str;
      default = [];
    };

    secretName = lib.mkOption {
      description = "Secret name, if null use the name of the backup instance.";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    repositories = lib.mkOption {
      description = lib.mdDoc "Repositories to back this instance to.";
      type = lib.types.nonEmptyListOf lib.types.str;
    };

    retention = lib.mkOption {
      description = "Retention options.";
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.int lib.types.nonEmptyStr ]);
      default = {
        keep_within = "1d";
        keep_hourly = 24;
        keep_daily = 7;
        keep_weekly = 4;
        keep_monthly = 6;
      };
    };

    consistency = lib.mkOption {
      description = "Consistency frequency options. Only applicable for borgmatic";
      type = lib.types.attrsOf lib.types.nonEmptyStr;
      default = {};
      example = {
        repository = "2 weeks";
        archives = "1 month";
      };
    };

    hooks = lib.mkOption {
      description = "Borgmatic hooks.";
      default = {};
      type = lib.types.submodule {
        options = {
          before_backup = lib.mkOption {
            description = "Hooks to run before backup";
            type = lib.types.listOf lib.types.str;
            default = [];
          };

          after_backup = lib.mkOption {
            description = "Hooks to run after backup";
            type = lib.types.listOf lib.types.str;
            default = [];
          };
        };
      };
    };

    environmentFile = lib.mkOption {
      type = lib.types.bool;
      description = "Add environment file to be read by the systemd service.";
      default = false;
      example = true;
    };
  };

  repoSlugName = name: builtins.replaceStrings ["/" ":"] ["_" "_"] (lib.strings.removePrefix "/" name);

in
{
  options.shb.backup = {
    onlyOnAC = lib.mkOption {
      description = lib.mdDoc "Run backups only if AC power is plugged in.";
      default = true;
      example = false;
      type = lib.types.bool;
    };

    user = lib.mkOption {
      description = lib.mdDoc "Unix user doing the backups.";
      type = lib.types.str;
      default = "backup";
    };

    group = lib.mkOption {
      description = lib.mdDoc "Unix group doing the backups.";
      type = lib.types.str;
      default = "backup";
    };

    instances = lib.mkOption {
      description = lib.mdDoc "Each instance is a backup setting";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = instanceOptions;
      });
    };

    borgServer = lib.mkOption {
      description = lib.mdDoc "Add borgbackup package so external backups can use this server as a remote.";
      default = false;
      example = true;
      type = lib.types.bool;
    };
  };

  config = lib.mkIf (cfg.instances != {}) (
    let
      borgmaticInstances = lib.attrsets.filterAttrs (k: i: i.backend == "borgmatic") cfg.instances;
      resticInstances = lib.attrsets.filterAttrs (k: i: i.backend == "restic") cfg.instances;
    in
      {
        users.users = {
          ${cfg.user} = {
            name = cfg.user;
            group = cfg.group;
            home = "/var/lib/backup";
            createHome = true;
            isSystemUser = true;
            extraGroups = [ "keys" ];
          };
        };
        users.groups = {
          ${cfg.group} = {
            name = cfg.group;
          };
        };

        sops.secrets =
          let
            mkSopsSecret = name: instance: (
              [
                {
                  "${instance.backend}/passphrases/${if isNull instance.secretName then name else instance.secretName}" = {
                    sopsFile = instance.keySopsFile;
                    mode = "0440";
                    owner = cfg.user;
                    group = cfg.group;
                  };
                }
              ] ++ lib.optional ((lib.filter (lib.strings.hasPrefix "s3") instance.repositories) != []) {
                "${instance.backend}/environmentfiles/${if isNull instance.secretName then name else instance.secretName}" = {
                  sopsFile = instance.keySopsFile;
                  mode = "0440";
                  owner = cfg.user;
                  group = cfg.group;
                };
              } ++ lib.optionals (instance.backend == "borgmatic") (lib.flatten (map (repository: {
                "${instance.backend}/keys/${repoSlugName repository}" = {
                  key = "${instance.backend}/keys/${if isNull instance.secretName then name else instance.secretName}";
                  sopsFile = instance.keySopsFile;
                  mode = "0440";
                  owner = cfg.user;
                  group = cfg.group;
                };
              }) instance.repositories))
            );
          in
            lib.mkMerge (lib.flatten (lib.attrsets.mapAttrsToList mkSopsSecret cfg.instances));

        systemd.timers.borgmatic = lib.mkIf (borgmaticInstances != {}) {
          timerConfig = {
            OnCalendar = "hourly";
          };
        };

        systemd.services.borgmatic = lib.mkIf (borgmaticInstances != {}) {
          serviceConfig = {
            User = cfg.user;
            Group = cfg.group;
            ExecStartPre = [ "" ]; # Do not sleep before starting.
            ExecStart = [ "" "${pkgs.borgmatic}/bin/borgmatic --verbosity -1 --syslog-verbosity 1" ];
            # For borgmatic, since we have only one service, we need to merge all environmentFile
            # from all instances.
            EnvironmentFile = lib.mapAttrsToList (name: value: value.environmentFile) cfg.instances;
          };
        };

        systemd.packages = lib.mkIf (borgmaticInstances != {}) [ pkgs.borgmatic ];
        environment.systemPackages = (
          lib.optionals cfg.borgServer [ pkgs.borgbackup ]
          ++ lib.optionals (borgmaticInstances != {}) [ pkgs.borgbackup pkgs.borgmatic ]
          ++ lib.optionals (resticInstances != {}) [ pkgs.restic ]
        );

        services.restic.backups =
          let
            mkRepositorySettings = name: instance: repository: {
              "${name}_${repoSlugName repository}" = {
                inherit (cfg) user;
                inherit repository;

                paths = instance.sourceDirectories;

                passwordFile = "/run/secrets/${instance.backend}/passphrases/${name}";

                initialize = true;

                timerConfig = {
                  OnCalendar = "00,12:00:00";
                  RandomizedDelaySec = "5m";
                };

                pruneOpts = lib.mapAttrsToList (name: value:
                  "--${builtins.replaceStrings ["_"] ["-"] name} ${builtins.toString value}"
                ) instance.retention;

                backupPrepareCommand = lib.strings.concatStringsSep "\n" instance.hooks.before_backup;

                backupCleanupCommand = lib.strings.concatStringsSep "\n" instance.hooks.after_backup;
              } // lib.attrsets.optionalAttrs (instance.environmentFile) {
                environmentFile = "/run/secrets/${instance.backend}/environmentfiles/${name}";
              } // lib.attrsets.optionalAttrs (builtins.length instance.excludePatterns > 0) {
                exclude = instance.excludePatterns;
              };
            };

            mkSettings = name: instance: builtins.map (mkRepositorySettings name instance) instance.repositories;
          in
            lib.mkMerge (lib.flatten (lib.attrsets.mapAttrsToList mkSettings resticInstances));

        environment.etc =
          let
            mkSettings = name: instance: {
              "borgmatic.d/${name}.yaml".text = lib.generators.toYAML {} {
                location =
                  {
                    source_directories = instance.sourceDirectories;
                    repositories = instance.repositories;
                  }
                  // (lib.attrsets.optionalAttrs (builtins.length instance.excludePatterns > 0) {
                    excludePatterns = instance.excludePatterns;
                  });

                storage = {
                  encryption_passcommand = "cat /run/secrets/borgmatic/passphrases/${if isNull instance.secretName then name else instance.secretName}";
                  borg_keys_directory = "/run/secrets/borgmatic/keys";
                };

                retention = instance.retention;
                consistency.checks =
                  let
                    mkCheck = name: frequency: {
                      inherit name frequency;
                    };
                  in
                    lib.attrsets.mapAttrsToList mkCheck instance.consistency;

                # hooks = lib.mkMerge [
                #   lib.optionalAttrs (builtins.length instance.hooks.before_backup > 0) {
                #     inherit (instance.hooks) before_backup;
                #   }
                #   lib.optionalAttrs (builtins.length instance.hooks.after_backup > 0) {
                #     inherit (instance.hooks) after_backup;
                #   }
                # ];
              };
            };
          in
            lib.mkMerge (lib.attrsets.mapAttrsToList mkSettings borgmaticInstances);
      });
}
