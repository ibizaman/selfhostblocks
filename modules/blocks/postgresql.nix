{ config, lib, pkgs, ... }:
let
  cfg = config.shb.postgresql;

  upgrade-script = old: new:
    let
      oldStr = builtins.toString old;
      newStr = builtins.toString new;

      oldPkg = pkgs.${"postgresql_${oldStr}"};
      newPkg = pkgs.${"postgresql_${newStr}"};
    in
      pkgs.writeScriptBin "upgrade-pg-cluster-${oldStr}-${newStr}" ''
        set -eux
        # XXX it's perhaps advisable to stop all services that depend on postgresql
        systemctl stop postgresql

        export NEWDATA="/var/lib/postgresql/${newPkg.psqlSchema}"
        export NEWBIN="${newPkg}/bin"

        export OLDDATA="/var/lib/postgresql/${oldPkg.psqlSchema}"
        export OLDBIN="${oldPkg}/bin"

        install -d -m 0700 -o postgres -g postgres "$NEWDATA"
        cd "$NEWDATA"
        sudo -u postgres $NEWBIN/initdb -D "$NEWDATA"

        sudo -u postgres $NEWBIN/pg_upgrade \
          --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
          --old-bindir $OLDBIN --new-bindir $NEWBIN \
          "$@"
      '';
in
{
  options.shb.postgresql = {
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

    ensures = lib.mkOption {
      description = "List of username, database and/or passwords that should be created.";
      type = lib.types.listOf (lib.types.submodule {
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
      });
      default = [];
    };
  };

  config =
    let
      commonConfig = {
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
        services.postgresql.ensureUsers = map ({ username, database, ... }: {
          name = username;
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }) ensureCfgs;
      };

      pwdConfig = ensureCfgs: {
        systemd.services.postgresql.postStart =
          let
            prefix = ''
            $PSQL -tA <<'EOF'
              DO $$
              DECLARE password TEXT;
              BEGIN
            '';
            suffix = ''
              END $$;
            EOF
            '';
            exec = { username, passwordFile, ... }: ''
            password := trim(both from replace(pg_read_file('${passwordFile}'), E'\n', '''));
            EXECUTE format('ALTER ROLE ${username} WITH PASSWORD '''%s''';', password);
            '';
            cfgsWithPasswords = builtins.filter (cfg: cfg.passwordFile != null) ensureCfgs;
          in
            if (builtins.length cfgsWithPasswords) == 0 then "" else
              prefix + (lib.concatStrings (map exec cfgsWithPasswords)) + suffix;
      };

      debugConfig = enableDebug: lib.mkIf enableDebug {
        services.postgresql.settings.shared_preload_libraries = "auto_explain, pg_stat_statements";
      };
    in
      lib.mkMerge ([
        commonConfig
        (dbConfig cfg.ensures)
        (pwdConfig cfg.ensures)
        (lib.mkIf cfg.enableTCPIP tcpConfig)
        (debugConfig cfg.debug)
        {
          environment.systemPackages = [
            (upgrade-script 13 14)
            (upgrade-script 14 15)
            (upgrade-script 15 16)
          ];
        }
      ]);
}
