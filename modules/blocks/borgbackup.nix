{ config, pkgs, lib, utils, ... }:

let
  cfg = config.shb.borgbackup;

  instanceOptions = {
    enable = lib.mkEnableOption "shb borgbackup";

    keySopsFile = lib.mkOption {
      description = "Sops file that holds this instance's repository key and passphrase.";
      type = lib.types.path;
      example = "secrets/backup.yaml";
    };

    encryptionKeyFile = lib.mkOption {
      description = "Encryption key for the backup.";
      type = lib.types.path;
    };

    encryption_passcommand = "cat /run/secrets/borgmatic/passphrases/${if isNull instance.secretName then name else instance.secretName}";
    borg_keys_directory = "/run/secrets/borgmatic/keys";

    sourceDirectories = lib.mkOption {
      description = "Source directories.";
      type = lib.types.nonEmptyListOf lib.types.str;
    };

    excludePatterns = lib.mkOption {
      description = "Exclude patterns.";
      type = lib.types.listOf lib.types.str;
      default = [];
    };

    secretName = lib.mkOption {
      description = "Secret name, if null use the name of the backup instance.";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    repositories = lib.mkOption {
      description = "Repositories to back this instance to.";
      type = lib.types.nonEmptyListOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Repository location";
          };

          timerConfig = lib.mkOption {
            type = lib.types.attrsOf utils.systemdUtils.unitOptions.unitOption;
            default = {
              OnCalendar = "daily";
              Persistent = true;
            };
            description = ''When to run the backup. See {manpage}`systemd.timer(5)` for details.'';
            example = {
              OnCalendar = "00:05";
              RandomizedDelaySec = "5h";
              Persistent = true;
            };
          };
        };
      });
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
      description = "Consistency frequency options.";
      type = lib.types.attrsOf lib.types.nonEmptyStr;
      default = {};
      example = {
        repository = "2 weeks";
        archives = "1 month";
      };
    };

    hooks = lib.mkOption {
      description = "Hooks to run before or after the backup.";
      default = {};
      type = lib.types.submodule {
        options = {
          beforeBackup = lib.mkOption {
            description = "Hooks to run before backup";
            type = lib.types.listOf lib.types.str;
            default = [];
          };

          afterBackup = lib.mkOption {
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
  options.shb.borgbackup = {
    user = lib.mkOption {
      description = "Unix user doing the backups.";
      type = lib.types.str;
      default = "backup";
    };

    group = lib.mkOption {
      description = "Unix group doing the backups.";
      type = lib.types.str;
      default = "backup";
    };

    instances = lib.mkOption {
      description = "Each instance is a backup setting";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = instanceOptions;
      });
    };

    borgServer = lib.mkOption {
      description = "Add borgbackup package so external backups can use this server as a remote.";
      default = false;
      example = true;
      type = lib.types.bool;
    };

    # Taken from https://github.com/HubbeKing/restic-kubernetes/blob/73bfbdb0ba76939a4c52173fa2dbd52070710008/README.md?plain=1#L23
    performance = lib.mkOption {
      description = "Reduce performance impact of backup jobs.";
      default = {};
      type = lib.types.submodule {
        options = {
          niceness = lib.mkOption {
            type = lib.types.ints.between (-20) 19;
            description = "nice priority adjustment, defaults to 15 for ~20% CPU time of normal-priority process";
            default = 15;
          };
          ioSchedulingClass = lib.mkOption {
            type = lib.types.enum [ "idle" "best-effort" "realtime" ];
            description = "ionice scheduling class, defaults to best-effort IO.";
            default = "best-effort";
          };
          ioPriority = lib.mkOption {
            type = lib.types.nullOr (lib.types.ints.between 0 7);
            description = "ionice priority, defaults to 7 for lowest priority IO.";
            default = 7;
          };
        };
      };
    };
  };

  config = lib.mkIf (cfg.instances != {}) (
    let
      enabledInstances = lib.attrsets.filterAttrs (k: i: i.enable) cfg.instances;
    in lib.mkMerge [
      # Secrets configuration
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
              ] ++ lib.optional ((lib.filter ({path, ...}: lib.strings.hasPrefix "s3" path) instance.repositories) != []) {
                "${instance.backend}/environmentfiles/${if isNull instance.secretName then name else instance.secretName}" = {
                  sopsFile = instance.keySopsFile;
                  mode = "0440";
                  owner = cfg.user;
                  group = cfg.group;
                };
              } ++ lib.optionals (instance.backend == "borgmatic") (lib.flatten (map ({path, ...}: {
                "${instance.backend}/keys/${repoSlugName path}" = {
                  key = "${instance.backend}/keys/${if isNull instance.secretName then name else instance.secretName}";
                  sopsFile = instance.keySopsFile;
                  mode = "0440";
                  owner = cfg.user;
                  group = cfg.group;
                };
              }) instance.repositories))
            );
          in
            lib.mkMerge (lib.flatten (lib.attrsets.mapAttrsToList mkSopsSecret enabledInstances));
      }
      # Borgmatic configuration
      {
        systemd.timers.borgmatic = lib.mkIf (enabledInstances != {}) {
          timerConfig = {
            OnCalendar = "hourly";
          };
        };

        systemd.services.borgmatic = lib.mkIf (enabledInstances != {}) {
          serviceConfig = {
            User = cfg.user;
            Group = cfg.group;
            ExecStartPre = [ "" ]; # Do not sleep before starting.
            ExecStart = [ "" "${pkgs.borgmatic}/bin/borgmatic --verbosity -1 --syslog-verbosity 1" ];
            # For borgmatic, since we have only one service, we need to merge all environmentFile
            # from all instances.
            EnvironmentFile = lib.mapAttrsToList (name: value: value.environmentFile) enabledInstances;
          };
        };

        systemd.packages = lib.mkIf (enabledInstances != {}) [ pkgs.borgmatic ];
        environment.systemPackages = (
          lib.optionals cfg.borgServer [ pkgs.borgbackup ]
          ++ lib.optionals (enabledInstances != {}) [ pkgs.borgbackup pkgs.borgmatic ]
        );

        environment.etc =
          let
            mkSettings = name: instance: {
              "borgmatic.d/${name}.yaml".text = lib.generators.toYAML {} {
                location =
                  {
                    source_directories = instance.sourceDirectories;
                    repositories = map ({path, ...}: path) instance.repositories;
                  }
                  // (lib.attrsets.optionalAttrs (builtins.length instance.excludePatterns > 0) {
                    excludePatterns = instance.excludePatterns;
                  });

                storage = {
                  encryption_passcommand = "cat ${instance.encryptionKeyFile}";
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
                #   lib.optionalAttrs (builtins.length instance.hooks.beforeBackup > 0) {
                #     inherit (instance.hooks) beforeBackup;
                #   }
                #   lib.optionalAttrs (builtins.length instance.hooks.afterBackup > 0) {
                #     inherit (instance.hooks) afterBackup;
                #   }
                # ];
              };
            };
          in
            lib.mkMerge (lib.attrsets.mapAttrsToList mkSettings enabledInstances);
      }
    ]);
}
