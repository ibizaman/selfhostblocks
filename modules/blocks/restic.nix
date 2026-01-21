{
  config,
  pkgs,
  lib,
  shb,
  utils,
  ...
}:

let
  cfg = config.shb.restic;

  inherit (lib)
    concatStringsSep
    filterAttrs
    flatten
    literalExpression
    optionals
    listToAttrs
    mapAttrsToList
    mkEnableOption
    mkOption
    mkMerge
    ;
  inherit (lib)
    hasPrefix
    mkIf
    nameValuePair
    optionalAttrs
    removePrefix
    ;
  inherit (lib.types)
    attrsOf
    enum
    int
    ints
    oneOf
    nonEmptyStr
    nullOr
    str
    submodule
    ;

  commonOptions =
    {
      name,
      prefix,
      config,
      ...
    }:
    {
      enable = mkEnableOption ''
        SelfHostBlocks' Restic block

        A disabled instance will not backup data anymore
        but still provides the helper tool to restore snapshots
      '';

      passphrase = lib.mkOption {
        description = "Encryption key for the backup repository.";
        type = lib.types.submodule {
          options = shb.contracts.secret.mkRequester {
            mode = "0400";
            owner = config.request.user;
            ownerText = "[shb.restic.${prefix}.<name>.request.user](#blocks-restic-options-shb.restic.${prefix}._name_.request.user)";
            restartUnits = [ (fullName name config.settings.repository) ];
            restartUnitsText = "[ [shb.restic.${prefix}.<name>.settings.repository](#blocks-restic-options-shb.restic.${prefix}._name_.settings.repository) ]";
          };
        };
      };

      repository = mkOption {
        description = "Repositories to back this instance to.";
        type = submodule {
          options = {
            path = mkOption {
              type = str;
              description = "Repository location";
            };

            secrets = mkOption {
              type = attrsOf shb.secretFileType;
              default = { };
              description = ''
                Secrets needed to access the repository where the backups will be stored.

                See [s3 config](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html#amazon-s3) for an example
                and [list](https://restic.readthedocs.io/en/latest/040_backup.html#environment-variables) for the list of all secrets.

              '';
              example = literalExpression ''
                {
                  AWS_ACCESS_KEY_ID.source = <path/to/secret>;
                  AWS_SECRET_ACCESS_KEY.source = <path/to/secret>;
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
        };
      };

      retention = mkOption {
        description = "For how long to keep backup files.";
        type = attrsOf (oneOf [
          int
          nonEmptyStr
        ]);
        default = {
          keep_within = "1d";
          keep_hourly = 24;
          keep_daily = 7;
          keep_weekly = 4;
          keep_monthly = 6;
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

  repoSlugName = name: builtins.replaceStrings [ "/" ":" ] [ "_" "_" ] (removePrefix "/" name);
  fullName = name: repository: "restic-backups-${name}_${repoSlugName repository.path}";
in
{
  imports = [
    ../../lib/module.nix
    ../blocks/monitoring.nix
  ];

  options.shb.restic = {
    enableDashboard = lib.mkEnableOption "the Backups SHB dashboard" // {
      default = true;
    };

    instances = mkOption {
      description = "Files to backup following the [backup contract](./shb.contracts-backup.html).";
      default = { };
      type = attrsOf (
        submodule (
          { name, config, ... }:
          {
            options = shb.contracts.backup.mkProvider {
              settings = mkOption {
                description = ''
                  Settings specific to the Restic provider.
                '';

                type = submodule {
                  options = commonOptions {
                    inherit name config;
                    prefix = "instances";
                  };
                };
              };

              resultCfg = {
                restoreScript = fullName name config.settings.repository;
                restoreScriptText = "${fullName "<name>" { path = "path/to/repository"; }}";

                backupService = "${fullName name config.settings.repository}.service";
                backupServiceText = "${fullName "<name>" { path = "path/to/repository"; }}.service";
              };
            };
          }
        )
      );
    };

    databases = mkOption {
      description = "Databases to backup following the [database backup contract](./shb.contracts-databasebackup.html).";
      default = { };
      type = attrsOf (
        submodule (
          { name, config, ... }:
          {
            options = shb.contracts.databasebackup.mkProvider {
              settings = mkOption {
                description = ''
                  Settings specific to the Restic provider.
                '';

                type = submodule {
                  options = commonOptions {
                    inherit name config;
                    prefix = "databases";
                  };
                };
              };

              resultCfg = {
                restoreScript = fullName name config.settings.repository;
                restoreScriptText = "${fullName "<name>" { path = "path/to/repository"; }}";

                backupService = "${fullName name config.settings.repository}.service";
                backupServiceText = "${fullName "<name>" { path = "path/to/repository"; }}.service";
              };
            };
          }
        )
      );
    };

    # Taken from https://github.com/HubbeKing/restic-kubernetes/blob/73bfbdb0ba76939a4c52173fa2dbd52070710008/README.md?plain=1#L23
    performance = mkOption {
      description = "Reduce performance impact of backup jobs.";
      default = { };
      type = submodule {
        options = {
          niceness = mkOption {
            type = ints.between (-20) 19;
            description = "nice priority adjustment, defaults to 15 for ~20% CPU time of normal-priority process";
            default = 15;
          };
          ioSchedulingClass = mkOption {
            type = enum [
              "idle"
              "best-effort"
              "realtime"
            ];
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

  config = mkIf (cfg.instances != { } || cfg.databases != { }) (
    let
      enabledInstances = filterAttrs (k: i: i.settings.enable) cfg.instances;
      enabledDatabases = filterAttrs (k: i: i.settings.enable) cfg.databases;
    in
    mkMerge [
      {
        environment.systemPackages = optionals (enabledInstances != { } || enabledDatabases != { }) [
          pkgs.restic
        ];
      }
      {
        # Create repository if it is a local path.
        systemd.tmpfiles.rules =
          let
            mkSettings =
              name: instance:
              optionals (hasPrefix "/" instance.settings.repository.path) [
                "d '${instance.settings.repository.path}' 0750 ${instance.request.user} root - -"
              ];
          in
          flatten (mapAttrsToList mkSettings (cfg.instances // cfg.databases));
      }
      {
        services.restic.backups =
          let
            mkSettings = name: instance: {
              "${name}_${repoSlugName instance.settings.repository.path}" = {
                inherit (instance.request) user;

                repository = instance.settings.repository.path;

                paths = instance.request.sourceDirectories;

                passwordFile = toString instance.settings.passphrase.result.path;

                initialize = true;

                inherit (instance.settings.repository) timerConfig;

                pruneOpts = mapAttrsToList (
                  name: value: "--${builtins.replaceStrings [ "_" ] [ "-" ] name} ${builtins.toString value}"
                ) instance.settings.retention;

                backupPrepareCommand = concatStringsSep "\n" instance.request.hooks.beforeBackup;

                backupCleanupCommand = concatStringsSep "\n" instance.request.hooks.afterBackup;

                extraBackupArgs =
                  (optionals (instance.settings.limitUploadKiBs != null) [
                    "--limit-upload=${toString instance.settings.limitUploadKiBs}"
                  ])
                  ++ (optionals (instance.settings.limitDownloadKiBs != null) [
                    "--limit-download=${toString instance.settings.limitDownloadKiBs}"
                  ]);
              }
              // optionalAttrs (builtins.length instance.request.excludePatterns > 0) {
                exclude = instance.request.excludePatterns;
              };
            };
          in
          mkMerge (flatten (mapAttrsToList mkSettings enabledInstances));
      }
      {
        services.restic.backups =
          let
            mkSettings = name: instance: {
              "${name}_${repoSlugName instance.settings.repository.path}" = {
                inherit (instance.request) user;

                repository = instance.settings.repository.path;

                dynamicFilesFrom = "echo";

                passwordFile = toString instance.settings.passphrase.result.path;

                initialize = true;

                inherit (instance.settings.repository) timerConfig;

                pruneOpts = mapAttrsToList (
                  name: value: "--${builtins.replaceStrings [ "_" ] [ "-" ] name} ${builtins.toString value}"
                ) instance.settings.retention;

                extraBackupArgs =
                  (optionals (instance.settings.limitUploadKiBs != null) [
                    "--limit-upload=${toString instance.settings.limitUploadKiBs}"
                  ])
                  ++ (optionals (instance.settings.limitDownloadKiBs != null) [
                    "--limit-download=${toString instance.settings.limitDownloadKiBs}"
                  ])
                  ++ (
                    let
                      cmd = pkgs.writeShellScriptBin "dump.sh" instance.request.backupCmd;
                    in
                    [
                      "--stdin-filename ${instance.request.backupName} --stdin-from-command -- ${cmd}/bin/dump.sh"
                    ]
                  );
              };
            };
          in
          mkMerge (flatten (mapAttrsToList mkSettings enabledDatabases));
      }
      {
        systemd.services =
          let
            mkSettings =
              name: instance:
              let
                serviceName = fullName name instance.settings.repository;
              in
              {
                ${serviceName} = mkMerge [
                  {
                    serviceConfig = {
                      Nice = cfg.performance.niceness;
                      IOSchedulingClass = cfg.performance.ioSchedulingClass;
                      IOSchedulingPriority = cfg.performance.ioPriority;
                      # BindReadOnlyPaths = instance.sourceDirectories;
                    };
                  }
                  (optionalAttrs (instance.settings.repository.secrets != { }) {
                    serviceConfig.EnvironmentFile = [
                      "/run/secrets_restic/${serviceName}"
                    ];
                    after = [ "${serviceName}-pre.service" ];
                    requires = [ "${serviceName}-pre.service" ];
                  })
                ];

                "${serviceName}-pre" = mkIf (instance.settings.repository.secrets != { }) (
                  let
                    script = shb.genConfigOutOfBandSystemd {
                      config = instance.settings.repository.secrets;
                      configLocation = "/run/secrets_restic/${serviceName}";
                      generator = shb.toEnvVar;
                      user = instance.request.user;
                    };
                  in
                  {
                    script = script.preStart;
                    serviceConfig.Type = "oneshot";
                    serviceConfig.LoadCredential = script.loadCredentials;
                  }
                );
              };
          in
          mkMerge (flatten (mapAttrsToList mkSettings (enabledInstances // enabledDatabases)));
      }
      {
        systemd.services =
          let
            mkEnv =
              name: instance:
              nameValuePair "${fullName name instance.settings.repository}_restore_gen" {
                enable = true;
                wantedBy = [ "multi-user.target" ];
                serviceConfig.Type = "oneshot";
                script = (
                  shb.replaceSecrets {
                    userConfig = instance.settings.repository.secrets // {
                      RESTIC_PASSWORD_FILE = toString instance.settings.passphrase.result.path;
                      RESTIC_REPOSITORY = instance.settings.repository.path;
                    };
                    resultPath = "/run/secrets_restic_env/${fullName name instance.settings.repository}";
                    generator = shb.toEnvVar;
                    user = instance.request.user;
                  }
                );
              };
          in
          listToAttrs (flatten (mapAttrsToList mkEnv (cfg.instances // cfg.databases)));
      }
      {
        environment.systemPackages =
          let
            mkResticBinary =
              name: instance:
              pkgs.writeShellApplication {
                name = fullName name instance.settings.repository;
                text = ''
                  usage() {
                    echo "$0 restore latest"
                  }

                  if ! [ "$1" = "restore" ]; then
                    usage
                    exit 1
                  fi
                  shift

                  if ! [ "$1" = "latest" ]; then
                    usage
                    exit 1
                  fi
                  shift

                  sudocmd() {
                    sudo --preserve-env=RESTIC_REPOSITORY,RESTIC_PASSWORD_FILE -u ${instance.request.user} "$@"
                  }

                  set -a
                  # shellcheck disable=SC1090
                  source <(sudocmd cat "/run/secrets_restic_env/${fullName name instance.settings.repository}")
                  set +a

                  echo "Will restore archive 'latest'"

                  sudocmd ${pkgs.restic}/bin/restic restore latest --target /
                '';
              };
          in
          flatten (mapAttrsToList mkResticBinary cfg.instances);
      }
      {
        environment.systemPackages =
          let
            mkResticBinary =
              name: instance:
              pkgs.writeShellApplication {
                name = fullName name instance.settings.repository;
                text = ''
                  usage() {
                    echo "$0 restore latest"
                  }

                  if ! [ "$1" = "restore" ]; then
                    usage
                    exit 1
                  fi
                  shift

                  if ! [ "$1" = "latest" ]; then
                    usage
                    exit 1
                  fi
                  shift

                  sudocmd() {
                    sudo --preserve-env=RESTIC_REPOSITORY,RESTIC_PASSWORD_FILE -u ${instance.request.user} "$@"
                  }

                  set -a
                  # shellcheck disable=SC1090
                  source <(sudocmd cat "/run/secrets_restic_env/${fullName name instance.settings.repository}")
                  set +a

                  echo "Will restore archive 'latest'"

                  sudocmd sh -c "${pkgs.restic}/bin/restic dump latest ${instance.request.backupName} | ${instance.request.restoreCmd}"
                '';
              };
          in
          flatten (mapAttrsToList mkResticBinary cfg.databases);
      }

      (lib.mkIf (cfg.enableDashboard && (cfg.instances != { } || cfg.databases != { })) {
        shb.monitoring.dashboards = [
          ./backup/dashboard/Backups.json
        ];
      })
    ]
  );
}
