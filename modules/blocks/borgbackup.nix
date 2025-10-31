{
  config,
  pkgs,
  lib,
  utils,
  ...
}:

let
  cfg = config.shb.borgbackup;

  contracts = pkgs.callPackage ../contracts { };

  inherit (lib)
    concatStringsSep
    filterAttrs
    flatten
    literalExpression
    optionals
    listToAttrs
    mapAttrsToList
    mkOption
    mkMerge
    ;
  inherit (lib)
    mkIf
    nameValuePair
    optionalAttrs
    removePrefix
    ;
  inherit (lib.types)
    attrsOf
    int
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
      enable = lib.mkEnableOption ''
        SelfHostBlocks' BorgBackup block;

        A disabled instance will not backup data anymore
        but still provides the helper tool to restore snapshots
      '';

      passphrase = lib.mkOption {
        description = "Encryption key for the backup repository.";
        type = lib.types.submodule {
          options = contracts.secret.mkRequester {
            mode = "0400";
            owner = config.request.user;
            ownerText = "[shb.borgbackup.${prefix}.<name>.request.user](#blocks-borgbackup-options-shb.borgbackup.${prefix}._name_.request.user)";
            restartUnits = [ (fullName name config.settings.repository) ];
            restartUnitsText = "[ [shb.borgbackup.${prefix}.<name>.settings.repository](#blocks-borgbackup-options-shb.borgbackup.${prefix}._name_.settings.repository) ]";
          };
        };
      };

      repository = lib.mkOption {
        description = "Repository to send the backups to.";
        type = submodule {
          options = {
            path = mkOption {
              type = str;
              description = "Repository location";
            };

            secrets = mkOption {
              type = attrsOf lib.shb.secretFileType;
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

      retention = lib.mkOption {
        description = "Retention options. See {command}`borg help prune` for the available options.";
        type = attrsOf (oneOf [
          int
          nonEmptyStr
        ]);
        default = {
          within = "1d";
          hourly = 24;
          daily = 7;
          weekly = 4;
          monthly = 6;
        };
      };

      consistency = lib.mkOption {
        description = "Consistency frequency options.";
        type = lib.types.attrsOf lib.types.nonEmptyStr;
        default = { };
        example = {
          repository = "2 weeks";
          archives = "1 month";
        };
      };

      limitUploadKiBs = mkOption {
        type = nullOr int;
        description = "Limit upload bandwidth to the given KiB/s amount.";
        default = null;
        example = 8000;
      };

      stateDir = mkOption {
        type = nullOr lib.types.str;
        description = ''
          Override the directory in which {command}`borg` stores its
          configuration and cache. By default it uses the user's
          home directory but is some cases this can cause conflicts.
        '';
        default = null;
      };
    };

  repoSlugName = name: builtins.replaceStrings [ "/" ":" ] [ "_" "_" ] (removePrefix "/" name);
  fullName = name: repository: "borgbackup-job-${name}_${repoSlugName repository.path}";
in
{
  options.shb.borgbackup = {
    instances = mkOption {
      description = "Files to backup following the [backup contract](./contracts-backup.html).";
      default = { };
      type = attrsOf (
        submodule (
          { name, config, ... }:
          {
            options = contracts.backup.mkProvider {
              settings = mkOption {
                description = ''
                  Settings specific to the BorgBackup provider.
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
      description = "Databases to backup following the [database backup contract](./contracts-databasebackup.html).";
      default = { };
      type = attrsOf (
        submodule (
          { name, config, ... }:
          {
            options = contracts.databasebackup.mkProvider {
              settings = mkOption {
                description = ''
                  Settings specific to the BorgBackup provider.
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

    borgServer = lib.mkOption {
      description = "Add borgbackup package to `environment.systemPackages` so external backups can use this server as a remote.";
      default = false;
      example = true;
      type = lib.types.bool;
    };

    # Taken from https://github.com/HubbeKing/restic-kubernetes/blob/73bfbdb0ba76939a4c52173fa2dbd52070710008/README.md?plain=1#L23
    performance = lib.mkOption {
      description = "Reduce performance impact of backup jobs.";
      default = { };
      type = lib.types.submodule {
        options = {
          niceness = lib.mkOption {
            type = lib.types.ints.between (-20) 19;
            description = "nice priority adjustment, defaults to 15 for ~20% CPU time of normal-priority process";
            default = 15;
          };
          ioSchedulingClass = lib.mkOption {
            type = lib.types.enum [
              "idle"
              "best-effort"
              "realtime"
            ];
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

  config = lib.mkIf (cfg.instances != { } || cfg.databases != { }) (
    let
      enabledInstances = filterAttrs (k: i: i.settings.enable) cfg.instances;
      enabledDatabases = filterAttrs (k: i: i.settings.enable) cfg.databases;
    in
    lib.mkMerge [
      {
        environment.systemPackages =
          optionals (cfg.borgServer || enabledInstances != { } || enabledDatabases != { })
            [
              pkgs.borgbackup
            ];
      }
      {
        services.borgbackup.jobs =
          let
            mkJob = name: instance: {
              "${name}_${repoSlugName instance.settings.repository.path}" = {
                inherit (instance.request) user;

                repo = instance.settings.repository.path;

                paths = instance.request.sourceDirectories;

                encryption.mode = "repokey-blake2";
                # We do not set encryption.passphrase here, we set BORG_PASSPHRASE_FD further down.
                encryption.passCommand = "cat ${instance.settings.passphrase.result.path}";

                doInit = true;
                failOnWarnings = true;
                stateDir = instance.settings.stateDir;

                persistentTimer = instance.settings.repository.timerConfig.Persistent or false;
                startAt = ""; # Some non-empty string value tricks the upstream module in creating the systemd timer.

                prune.keep = instance.settings.retention;

                preHook = concatStringsSep "\n" instance.request.hooks.beforeBackup;

                postHook = concatStringsSep "\n" instance.request.hooks.afterBackup;

                extraArgs = (
                  optionals (instance.settings.limitUploadKiBs != null) [
                    "--upload-ratelimit=${toString instance.settings.limitUploadKiBs}"
                  ]
                );

                exclude = instance.request.excludePatterns;
              };
            };
          in
          mkMerge (mapAttrsToList mkJob enabledInstances);
      }
      {
        services.borgbackup.jobs =
          let
            mkJob = name: instance: {
              "${name}_${repoSlugName instance.settings.repository.path}" = {
                inherit (instance.request) user;

                repo = instance.settings.repository.path;

                dumpCommand = lib.getExe (pkgs.writeShellApplication {
                  name = "dump-command";
                  text = instance.request.backupCmd;
                });

                encryption.mode = "repokey-blake2";
                # We do not set encryption.passphrase here, we set BORG_PASSPHRASE_FD further down.
                encryption.passCommand = "cat ${instance.settings.passphrase.result.path}";

                doInit = true;
                failOnWarnings = true;
                stateDir = instance.settings.stateDir;

                persistentTimer = instance.settings.repository.timerConfig.Persistent or false;
                startAt = ""; # Some non-empty list value that tricks upstream in creating the systemd timer.

                prune.keep = instance.settings.retention;

                extraArgs = (
                  optionals (instance.settings.limitUploadKiBs != null) [
                    "--upload-ratelimit=${toString instance.settings.limitUploadKiBs}"
                  ]
                );
              };
            };
          in
          mkMerge (mapAttrsToList mkJob enabledDatabases);
      }
      {
        systemd.timers =
          let
            mkTimer = name: instance: {
              ${fullName name instance.settings.repository} = {
                timerConfig = lib.mkForce instance.settings.repository.timerConfig;
              };
            };
          in
          mkMerge (mapAttrsToList mkTimer (enabledInstances // enabledDatabases));
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
                      # Makes the systemd service wait for the backup to be done before changing state to inactive.
                      Type = "oneshot";
                      Nice = lib.mkForce cfg.performance.niceness;
                      IOSchedulingClass = lib.mkForce cfg.performance.ioSchedulingClass;
                      IOSchedulingPriority = lib.mkForce cfg.performance.ioPriority;
                      # BindReadOnlyPaths = instance.sourceDirectories;
                    };
                  }
                  (optionalAttrs (instance.settings.repository.secrets != { }) {
                    serviceConfig.EnvironmentFile = [
                      "/run/secrets_borgbackup/${serviceName}"
                    ];
                    after = [ "${serviceName}-pre.service" ];
                    requires = [ "${serviceName}-pre.service" ];
                  })
                ];

                "${serviceName}-pre" = mkIf (instance.settings.repository.secrets != { }) (
                  let
                    script = lib.shb.genConfigOutOfBandSystemd {
                      config = instance.settings.repository.secrets;
                      configLocation = "/run/secrets_borgbackup/${serviceName}";
                      generator = lib.shb.toEnvVar;
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
                  lib.shb.replaceSecrets {
                    userConfig = instance.settings.repository.secrets // {
                      BORG_PASSCOMMAND = ''"cat ${instance.settings.passphrase.result.path}"'';
                      BORG_REPO = instance.settings.repository.path;
                    };
                    resultPath = "/run/secrets_borgbackup_env/${fullName name instance.settings.repository}";
                    generator = lib.shb.toEnvVar;
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
            mkBorgBackupBinary =
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
                    sudo --preserve-env=BORG_REPO,BORG_PASSCOMMAND -u ${instance.request.user} "$@"
                  }

                  set -a
                  # shellcheck disable=SC1090
                  source <(sudocmd cat "/run/secrets_borgbackup_env/${fullName name instance.settings.repository}")
                  set +a

                  archive="$(sudocmd borg list --short "$BORG_REPO" | tail -n 1)"
                  echo "Will restore archive $archive"

                  (cd / && sudocmd ${pkgs.borgbackup}/bin/borg extract "$BORG_REPO"::"$archive")
                '';
              };
          in
          flatten (mapAttrsToList mkBorgBackupBinary cfg.instances);
      }
      {
        environment.systemPackages =
          let
            mkBorgBackupBinary =
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
                    sudo --preserve-env=BORG_REPO,BORG_PASSCOMMAND -u ${instance.request.user} "$@"
                  }

                  set -a
                  # shellcheck disable=SC1090
                  source <(sudocmd cat "/run/secrets_borgbackup_env/${fullName name instance.settings.repository}")
                  set +a

                  archive="$(sudocmd borg list --short "$BORG_REPO" | tail -n 1)"
                  echo "Will restore archive $archive"

                  sudocmd sh -c "${pkgs.borgbackup}/bin/borg extract $BORG_REPO::$archive --stdout | ${instance.request.restoreCmd}"
                '';
              };
          in
          flatten (mapAttrsToList mkBorgBackupBinary cfg.databases);
      }
    ]
  );
}
