{ config, pkgs, lib, utils, ... }:

let
  cfg = config.shb.restic;

  shblib = pkgs.callPackage ../../lib {};

  instanceOptions = {
    enable = lib.mkEnableOption "shb restic";

    passphraseFile = lib.mkOption {
      description = "Encryption key for the backups.";
      type = lib.types.path;
    };

    user = lib.mkOption {
      description = ''
        Unix user doing the backups.

        For Restic, the same user must be used for all instances.
      '';
      type = lib.types.str;
      readOnly = true;
      default = cfg.user;
    };

    group = lib.mkOption {
      description = ''
        Unix group doing the backups.

        For Restic, the same group must be used for all instances.
      '';
      type = lib.types.str;
      readOnly = true;
      default = cfg.group;
    };

    sourceDirectories = lib.mkOption {
      description = "Source directories.";
      type = lib.types.nonEmptyListOf lib.types.str;
    };

    excludePatterns = lib.mkOption {
      description = "Exclude patterns.";
      type = lib.types.listOf lib.types.str;
      default = [];
    };

    repositories = lib.mkOption {
      description = "Repositories to back this instance to.";
      type = lib.types.nonEmptyListOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Repository location";
          };

          extraSecrets = lib.mkOption {
            type = lib.types.attrsOf shblib.secretFileType;
            default = {};
            description = ''
              Extra secrets needed to access the repository where the backups will be stored.

              See [s3 config](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html#amazon-s3) for an example.
              '';
            example = lib.literalExpression ''
              {
                AWS_ACCESS_KEY_ID = <path/to/secret>;
                AWS_SECRET_ACCESS_KEY = <path/to/secret>;
              }
              '';
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
      description = "For how long to keep backup files.";
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.int lib.types.nonEmptyStr ]);
      default = {
        keep_within = "1d";
        keep_hourly = 24;
        keep_daily = 7;
        keep_weekly = 4;
        keep_monthly = 6;
      };
    };

    hooks = lib.mkOption {
      description = "Hooks to run before or after the backup.";
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
  };

  repoSlugName = name: builtins.replaceStrings ["/" ":"] ["_" "_"] (lib.strings.removePrefix "/" name);
in
{
  options.shb.restic = {
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
            description = "ionice scheduling class, defaults to best-effort IO. Only used for `restic backup`, `restic forget` and `restic check` commands.";
            default = "best-effort";
          };
          ioPriority = lib.mkOption {
            type = lib.types.nullOr (lib.types.ints.between 0 7);
            description = "ionice priority, defaults to 7 for lowest priority IO. Only used for `restic backup`, `restic forget` and `restic check` commands.";
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
      {
        assertions = [
          {
            assertion = lib.all (x: x.user == cfg.user) (lib.mapAttrsToList (n: v: v)cfg.instances);
            message = "All Restic instances must have the same user as 'shb.restic.user'.";
          }
          {
            assertion = lib.all (x: x.group == cfg.group) (lib.mapAttrsToList (n: v: v) cfg.instances);
            message = "All Restic instances must have the same group as 'shb.restic.group'.";
          }
        ];

        users.users = {
          ${cfg.user} = {
            name = cfg.user;
            group = cfg.group;
            home = lib.mkForce "/var/lib/${cfg.user}";
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
      }
      {
        environment.systemPackages = lib.optionals (enabledInstances != {}) [ pkgs.restic ];

        services.restic.backups =
          let
            mkRepositorySettings = name: instance: repository: {
              "${name}_${repoSlugName repository.path}" = {
                inherit (cfg) user;
                repository = repository.path;

                paths = instance.sourceDirectories;

                passwordFile = toString instance.passphraseFile;

                initialize = true;

                inherit (repository) timerConfig;

                pruneOpts = lib.mapAttrsToList (name: value:
                  "--${builtins.replaceStrings ["_"] ["-"] name} ${builtins.toString value}"
                ) instance.retention;

                backupPrepareCommand = lib.strings.concatStringsSep "\n" instance.hooks.before_backup;

                backupCleanupCommand = lib.strings.concatStringsSep "\n" instance.hooks.after_backup;
              } // lib.attrsets.optionalAttrs (repository.extraSecrets != {}) {
                environmentFile = shblib.replaceSecrets {
                  userConfig = repository.extraSecrets;
                  resultPath = "/var/lib/backup/${name}";
                  generator = name: v: pkgs.writeText "template" (lib.generators.toINIWithGlobalSection {} v);
                };
              } // lib.attrsets.optionalAttrs (builtins.length instance.excludePatterns > 0) {
                exclude = instance.excludePatterns;
              };
            };

            mkSettings = name: instance: builtins.map (mkRepositorySettings name instance) instance.repositories;
          in
            lib.mkMerge (lib.flatten (lib.attrsets.mapAttrsToList mkSettings enabledInstances));

        systemd.services =
          let
            mkRepositorySettings = name: instance: repository: {
              "restic-backups-${name}_${repoSlugName repository.path}".serviceConfig = {
                Nice = cfg.performance.niceness;
                IOSchedulingClass = cfg.performance.ioSchedulingClass;
                IOSchedulingPriority = cfg.performance.ioPriority;
              };
            };
            mkSettings = name: instance: builtins.map (mkRepositorySettings name instance) instance.repositories;
          in
            lib.mkMerge (lib.flatten (lib.attrsets.mapAttrsToList mkSettings enabledInstances));
      }
      {
        environment.systemPackages = let
          mkResticBinary = name: instance: repository: pkgs.writeShellScriptBin "restic-${name}_${repoSlugName repository.path}" ''
            export RESTIC_PASSWORD_FILE=${instance.passphraseFile}
            export RESTIC_REPOSITORY=${repository.path}
            ${pkgs.restic}/bin/restic $@
          '';
          mkSettings = name: instance: builtins.map (mkResticBinary name instance) instance.repositories;
        in
          lib.flatten (lib.attrsets.mapAttrsToList mkSettings enabledInstances);
      }
    ]);
}
