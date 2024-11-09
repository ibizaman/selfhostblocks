{ config, pkgs, lib, utils, ... }:

let
  cfg = config.shb.restic;

  shblib = pkgs.callPackage ../../lib {};

  inherit (lib) concatStringsSep filterAttrs flatten literalExpression optionals optionalString listToAttrs mapAttrsToList mkEnableOption mkOption mkMerge;
  inherit (lib) generators hasPrefix mkIf nameValuePair optionalAttrs removePrefix;
  inherit (lib.types) attrsOf enum int ints listOf oneOf nonEmptyListOf nonEmptyStr nullOr path str submodule;

  instanceOptions = {
    enable = mkEnableOption "shb restic. A disabled instance will not backup data anymore but still provides the helper tool to introspect and rollback snapshots";

    passphraseFile = mkOption {
      description = "Encryption key for the backups.";
      type = path;
    };

    user = mkOption {
      description = ''
        Unix user doing the backups. Must be the user owning the files to be backed up.
      '';
      type = str;
    };

    sourceDirectories = mkOption {
      description = "Source directories.";
      type = nonEmptyListOf str;
    };

    excludePatterns = mkOption {
      description = "Exclude patterns.";
      type = listOf str;
      default = [];
    };

    repositories = mkOption {
      description = "Repositories to back this instance to.";
      type = nonEmptyListOf (submodule {
        options = {
          path = mkOption {
            type = str;
            description = "Repository location";
          };

          secrets = mkOption {
            type = attrsOf shblib.secretFileType;
            default = {};
            description = ''
              Secrets needed to access the repository where the backups will be stored.

              See [s3 config](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html#amazon-s3) for an example
              and [list](https://restic.readthedocs.io/en/latest/040_backup.html#environment-variables) for the list of all secrets.

              '';
            example = literalExpression ''
              {
                AWS_ACCESS_KEY_ID = <path/to/secret>;
                AWS_SECRET_ACCESS_KEY = <path/to/secret>;
              }
              '';
          };

          timerConfig = mkOption {
            type = attrsOf utils.systemdUtils.unitOptions.unitOption;
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

    retention = mkOption {
      description = "For how long to keep backup files.";
      type = attrsOf (oneOf [ int nonEmptyStr ]);
      default = {
        keep_within = "1d";
        keep_hourly = 24;
        keep_daily = 7;
        keep_weekly = 4;
        keep_monthly = 6;
      };
    };

    hooks = mkOption {
      description = "Hooks to run before or after the backup.";
      default = {};
      type = submodule {
        options = {
          before_backup = mkOption {
            description = "Hooks to run before backup";
            type = listOf str;
            default = [];
          };

          after_backup = mkOption {
            description = "Hooks to run after backup";
            type = listOf str;
            default = [];
          };
        };
      };
    };

    limitUploadKiBs = mkOption {
      type = nullOr int;
      description = "Limit upload bandwidth to the given KiB/s amount.";
      default = null;
      example = 8000;
    };

    limitDownloadKiBs = mkOption {
      type = nullOr int;
      description = "Limit download bandwidth to the given KiB/s amount.";
      default = null;
      example = 8000;
    };
  };

  repoSlugName = name: builtins.replaceStrings ["/" ":"] ["_" "_"] (removePrefix "/" name);
  backupName = name: repository: "${name}_${repoSlugName repository.path}";
  fullName = name: repository: "restic-backups-${name}_${repoSlugName repository.path}";
in
{
  options.shb.restic = {
    instances = mkOption {
      description = "Each instance is a backup setting";
      default = {};
      type = attrsOf (submodule {
        options = instanceOptions;
      });
    };

    # Taken from https://github.com/HubbeKing/restic-kubernetes/blob/73bfbdb0ba76939a4c52173fa2dbd52070710008/README.md?plain=1#L23
    performance = mkOption {
      description = "Reduce performance impact of backup jobs.";
      default = {};
      type = submodule {
        options = {
          niceness = mkOption {
            type = ints.between (-20) 19;
            description = "nice priority adjustment, defaults to 15 for ~20% CPU time of normal-priority process";
            default = 15;
          };
          ioSchedulingClass = mkOption {
            type = enum [ "idle" "best-effort" "realtime" ];
            description = "ionice scheduling class, defaults to best-effort IO. Only used for `restic backup`, `restic forget` and `restic check` commands.";
            default = "best-effort";
          };
          ioPriority = mkOption {
            type = nullOr (ints.between 0 7);
            description = "ionice priority, defaults to 7 for lowest priority IO. Only used for `restic backup`, `restic forget` and `restic check` commands.";
            default = 7;
          };
        };
      };
    };
  };

  config = mkIf (cfg.instances != {}) (
    let
      enabledInstances = filterAttrs (k: i: i.enable) cfg.instances;
    in mkMerge [
      {
        environment.systemPackages = optionals (enabledInstances != {}) [ pkgs.restic ];

        systemd.tmpfiles.rules =
          let
            mkRepositorySettings = name: instance: repository: optionals (hasPrefix "/" repository.path) [
              "d '${repository.path}' 0750 ${instance.user} root - -"
            ];

            mkSettings = name: instance: builtins.map (mkRepositorySettings name instance) instance.repositories;
          in
            flatten (mapAttrsToList mkSettings cfg.instances);

        services.restic.backups =
          let
            mkRepositorySettings = name: instance: repository: {
              "${name}_${repoSlugName repository.path}" = {
                inherit (instance) user;

                repository = repository.path;

                paths = instance.sourceDirectories;

                passwordFile = toString instance.passphraseFile;

                initialize = true;

                inherit (repository) timerConfig;

                pruneOpts = mapAttrsToList (name: value:
                  "--${builtins.replaceStrings ["_"] ["-"] name} ${builtins.toString value}"
                ) instance.retention;

                backupPrepareCommand = concatStringsSep "\n" instance.hooks.before_backup;

                backupCleanupCommand = concatStringsSep "\n" instance.hooks.after_backup;
              } // optionalAttrs (builtins.length instance.excludePatterns > 0) {
                exclude = instance.excludePatterns;

                extraBackupArgs =
                  (optionals (instance.limitUploadKiBs != null) [
                    "--limit-upload=${toString instance.limitUploadKiBs}"
                  ])
                  ++ (optionals (instance.limitDownloadKiBs != null) [
                    "--limit-download=${toString instance.limitDownloadKiBs}"
                  ]);
              };
            };

            mkSettings = name: instance: builtins.map (mkRepositorySettings name instance) instance.repositories;
          in
            mkMerge (flatten (mapAttrsToList mkSettings enabledInstances));

        systemd.services =
          let
            mkRepositorySettings = name: instance: repository:
              let
                serviceName = fullName name repository;
              in
                {
                  ${serviceName} = mkMerge [
                    {
                      serviceConfig = {
                        Nice = cfg.performance.niceness;
                        IOSchedulingClass = cfg.performance.ioSchedulingClass;
                        IOSchedulingPriority = cfg.performance.ioPriority;
                        BindReadOnlyPaths = instance.sourceDirectories;
                      };
                    }
                    (optionalAttrs (repository.secrets != {})
                      {
                        serviceConfig.EnvironmentFile = [
                          "/run/secrets_restic/${serviceName}"
                        ];
                        after = [ "${serviceName}-pre.service" ];
                        requires = [ "${serviceName}-pre.service" ];
                      })
                  ];

                  "${serviceName}-pre" = mkIf (repository.secrets != {})
                    (let
                      script = shblib.genConfigOutOfBandSystemd {
                        config = repository.secrets;
                        configLocation = "/run/secrets_restic/${serviceName}";
                        generator = name: v: pkgs.writeText "template" (generators.toINIWithGlobalSection {} { globalSection = v; });
                        user = instance.user;
                      };
                    in
                      {
                        script = script.preStart;
                        serviceConfig.Type = "oneshot";
                        serviceConfig.LoadCredential = script.loadCredentials;
                      });
            };
            mkSettings = name: instance: builtins.map (mkRepositorySettings name instance) instance.repositories;
          in
            mkMerge (flatten (mapAttrsToList mkSettings enabledInstances));
      }
      {
        system.activationScripts = let
          mkEnv = name: instance: repository:
            nameValuePair "${fullName name repository}_gen"
              (shblib.replaceSecrets {
                userConfig = repository.secrets // {
                  RESTIC_PASSWORD_FILE = instance.passphraseFile;
                  RESTIC_REPOSITORY = repository.path;
                };
                resultPath = "/run/secrets_restic_env/${fullName name repository}";
                generator = name: v: pkgs.writeText (fullName name repository) (generators.toINIWithGlobalSection {} { globalSection = v; });
                user = instance.user;
              });
          mkSettings = name: instance: builtins.map (mkEnv name instance) instance.repositories;
        in
          listToAttrs (flatten (mapAttrsToList mkSettings cfg.instances));

        environment.systemPackages = let
          mkResticBinary = name: instance: repository:
            pkgs.writeShellScriptBin (fullName name repository) ''
              export $(grep -v '^#' "/run/secrets_restic_env/${fullName name repository}" \
                       | xargs -d '\n')
              ${pkgs.restic}/bin/restic $@
              '';
          mkSettings = name: instance: builtins.map (mkResticBinary name instance) instance.repositories;
        in
          flatten (mapAttrsToList mkSettings cfg.instances);
      }
    ]);
}
