{
  config,
  lib,
  pkgs,
  shb,
  ...
}:
let
  cfg = config.shb.postgresql;

  # The fallback supports the manual's isolated option evaluation.
  postgresqlPackage = config.services.postgresql.finalPackage or pkgs.postgresql;

  supportedVersions = [
    15
    16
    17
    18
  ];

  packageForVersion = version: pkgs.${"postgresql_${toString version}"};

  upgradeScript =
    old: new:
    let
      oldStr = builtins.toString old;
      newStr = builtins.toString new;

      oldPkg = packageForVersion old;
      newPkg = packageForVersion new;
    in
    pkgs.writeShellApplication {
      name = "upgrade-pg-cluster-${oldStr}-${newStr}";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gnused
        pkgs.sudo
        pkgs.systemd
      ];
      text = ''
        # Require root because the helper creates PostgreSQL-owned directories.
        if [[ "$EUID" -ne 0 ]]; then
          echo "Run this command as root." >&2
          exit 1
        fi

        # Refuse to migrate while the server may still be writing to the source cluster.
        if systemctl --quiet is-active postgresql.service; then
          echo "Stop PostgreSQL and its dependent services before upgrading." >&2
          exit 1
        fi

        # This helper supports only a one-step upgrade.
        for arg in "$@"; do
          if [[ "$arg" == "--check" || "$arg" == "-c" ]]; then
            echo "--check is not supported; run this helper without it to perform the upgrade." >&2
            exit 1
          fi
        done

        oldData="/var/lib/postgresql/${oldPkg.psqlSchema}"
        oldBin="${oldPkg}/bin"
        newData="/var/lib/postgresql/${newPkg.psqlSchema}"
        newBin="${newPkg}/bin"

        # Require the source cluster's version marker.
        if [[ ! -f "$oldData/PG_VERSION" ]]; then
          echo "PostgreSQL ${oldStr} cluster not found at $oldData." >&2
          exit 1
        fi

        read -r oldVersion < "$oldData/PG_VERSION"
        # Verify that the source cluster matches this helper's source version.
        if [[ "$oldVersion" != "${oldStr}" ]]; then
          echo "Expected PostgreSQL ${oldStr} at $oldData, found version $oldVersion." >&2
          exit 1
        fi

        # Require a missing target path, including when a dangling symlink occupies it.
        if [[ -e "$newData" || -L "$newData" ]]; then
          echo "$newData already exists; refusing to initialize it." >&2
          exit 1
        fi

        # PostgreSQL 18 enables checksums by default, but pg_upgrade requires both clusters to match.
        checksumVersion="$(
          "$oldBin/pg_controldata" "$oldData" \
            | sed -n 's/^Data page checksum version:[[:space:]]*//p'
        )"
        initdbArgs=(--pgdata="$newData")
        case "$checksumVersion" in
          0)
            ${lib.optionalString (new >= 18) "initdbArgs+=(--no-data-checksums)"}
            ;;
          1) initdbArgs+=(--data-checksums) ;;
          *)
            echo "Could not determine the checksum setting of $oldData." >&2
            exit 1
            ;;
        esac

        install -d -m 0700 -o postgres -g postgres "$newData"
        # Expand each initdb argument without joining or word splitting.
        sudo --user=postgres "$newBin/initdb" "''${initdbArgs[@]}"

        cd "$newData"
        # Forward caller-supplied pg_upgrade options without joining or word splitting.
        exec sudo --user=postgres "$newBin/pg_upgrade" \
          --old-datadir="$oldData" \
          --new-datadir="$newData" \
          --old-bindir="$oldBin" \
          --new-bindir="$newBin" \
          "$@"
      '';
    };
in
{
  imports = [
    ../../lib/module.nix
  ];

  options.shb.postgresql = {
    version = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum supportedVersions);
      default = null;
      example = 18;
      description = ''
        PostgreSQL major version managed by SelfHostBlocks. This must be set
        when PostgreSQL is enabled. The null default provides a migration error
        for configurations that have not selected their existing major yet.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Enable debugging options.

        Currently enables shared_preload_libraries = "auto_explain, pg_stat_statements"

        See https://www.postgresql.org/docs/current/pgstatstatements.html'';
      default = false;
    };
    enableTCPIP = lib.mkOption {
      type = lib.types.bool;
      description = "Enable TCP/IP connection on given port.";
      default = false;
    };

    databasebackup = lib.mkOption {
      description = ''
        Backup configuration.
      '';

      default = { };
      type = lib.types.submodule {
        options = shb.contracts.databasebackup.mkRequester {
          user = "postgres";

          backupName = "postgres.sql";

          backupCmd = ''
            ${postgresqlPackage}/bin/pg_dumpall --clean --if-exists | ${pkgs.gzip}/bin/gzip --rsyncable
          '';

          restoreCmd = ''
            ${pkgs.gzip}/bin/gunzip | sudo -u postgres ${postgresqlPackage}/bin/psql
          '';
        };
      };
    };

    ensures = lib.mkOption {
      description = "List of username, database and/or passwords that should be created.";
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            username = lib.mkOption {
              type = lib.types.str;
              description = "Postgres user name.";
            };

            database = lib.mkOption {
              type = lib.types.str;
              description = "Postgres database.";
            };

            passwordFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              description = "Optional password file for the postgres user. If not given, only peer auth is accepted for this user, otherwise password auth is allowed.";
              default = null;
              example = "/run/secrets/postgresql/password";
            };
          };
        }
      );
      default = [ ];
    };
  };

  config =
    let
      commonConfig = {
        systemd.services.postgresql.serviceConfig.Restart = "always";

        services.postgresql.settings = {
        };
      };

      tcpConfig = {
        services.postgresql.enableTCPIP = true;
        services.postgresql.authentication = lib.mkOverride 10 ''
          #type database DBuser origin-address auth-method
          local all      all    peer
          # ipv4
          host  all      all    127.0.0.1/32   password
          # ipv6
          host  all      all    ::1/128        password
        '';
      };

      dbConfig = ensureCfgs: {
        services.postgresql.enable = lib.mkDefault ((builtins.length ensureCfgs) > 0);
        services.postgresql.ensureDatabases = map ({ database, ... }: database) ensureCfgs;
        services.postgresql.ensureUsers = map (
          { username, database, ... }:
          {
            name = username;
            ensureDBOwnership = true;
            ensureClauses.login = true;
          }
        ) ensureCfgs;
      };

      pwdConfig = ensureCfgs: {
        systemd.services.postgresql-setup.script = lib.mkAfter (
          let
            prefix = ''
              psql -tA <<'EOF'
                DO $$
                DECLARE password TEXT;
                BEGIN
            '';
            suffix = ''
                END $$;
              EOF
            '';
            exec =
              { username, passwordFile, ... }:
              ''
                password := trim(both from replace(pg_read_file('${passwordFile}'), E'\n', '''));
                EXECUTE format('ALTER ROLE "${username}" WITH PASSWORD '''%s''';', password);
              '';
            cfgsWithPasswords = builtins.filter (cfg: cfg.passwordFile != null) ensureCfgs;
          in
          if (builtins.length cfgsWithPasswords) == 0 then
            ""
          else
            prefix + (lib.concatStrings (map exec cfgsWithPasswords)) + suffix
        );
      };

      debugConfig =
        enableDebug:
        lib.mkIf enableDebug {
          services.postgresql.settings.shared_preload_libraries = "auto_explain, pg_stat_statements";
        };

      versionConfig = lib.mkIf (cfg.version != null) {
        services.postgresql.package = packageForVersion cfg.version;

        systemd.services.postgresql = lib.mkIf config.services.postgresql.enable {
          preStart = lib.mkBefore ''
            dataDir=${lib.escapeShellArg config.services.postgresql.dataDir}
            expectedVersion=${lib.escapeShellArg (toString cfg.version)}

            if [[ -f "$dataDir/PG_VERSION" ]]; then
              read -r actualVersion < "$dataDir/PG_VERSION"
              if [[ "$actualVersion" != "$expectedVersion" ]]; then
                echo "Expected PostgreSQL $expectedVersion at $dataDir, found version $actualVersion." >&2
                exit 1
              fi
            else
              for versionFile in /var/lib/postgresql/*/PG_VERSION; do
                if [[ -f "$versionFile" ]]; then
                  echo "Found an existing PostgreSQL cluster at ''${versionFile%/PG_VERSION}." >&2
                  # systemd creates StateDirectory before running preStart.
                  if [[ -d "$dataDir" && -z "$(ls -A "$dataDir")" ]]; then
                    echo "Remove the empty target directory $dataDir before running the upgrade helper." >&2
                  fi
                  echo "Run the matching upgrade-pg-cluster helper before selecting PostgreSQL $expectedVersion." >&2
                  exit 1
                fi
              done
            fi
          '';
        };
      };
    in
    lib.mkMerge ([
      commonConfig
      {
        assertions = [
          {
            assertion = !config.services.postgresql.enable || cfg.version != null;
            message = ''
              PostgreSQL is enabled but `shb.postgresql.version` is not set.
              Set it to the major version of the existing PostgreSQL cluster before rebuilding.
              See https://shb.skarabox.com/blocks-postgresql.html#blocks-postgresql-version.
            '';
          }
        ];
      }
      (dbConfig cfg.ensures)
      (pwdConfig cfg.ensures)
      (lib.mkIf cfg.enableTCPIP tcpConfig)
      (debugConfig cfg.debug)
      versionConfig
      {
        environment.systemPackages =
          lib.optionals (config.services.postgresql.enable && cfg.version != null)
            (
              map (upgradeScript cfg.version) (
                builtins.filter (targetVersion: targetVersion > cfg.version) supportedVersions
              )
            );
      }
    ]);
}
