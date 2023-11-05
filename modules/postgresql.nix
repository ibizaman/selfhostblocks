{ config, lib, ... }:
let
  cfg = config.shb.postgresql;
in
{
  options.shb.postgresql = {
    tcpIPPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      description = "Enable TCP/IP connection on given port.";
      default = null;
    };

    passwords = lib.mkOption {
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
            description = "Optional password file for the postgres user.";
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
      tcpConfig = port: {
        services.postgresql.enableTCPIP = true;
        services.postgresql.port = port;
        services.postgresql.authentication = lib.mkOverride 10 ''
          #type database DBuser origin-address auth-method
          # ipv4
          host  all      all     127.0.0.1/32   trust
          # ipv6
          host all       all     ::1/128        trust
        '';
      };

      dbConfig = passwordCfgs: {
        services.postgresql.enable = lib.mkDefault ((builtins.length passwordCfgs) > 0);
        services.postgresql.ensureDatabases = map ({ database, ... }: database) passwordCfgs;
        services.postgresql.ensureUsers = map ({ username, database, ... }: {
          name = username;
          ensurePermissions = {
            "DATABASE ${database}" = "ALL PRIVILEGES";
          };
          ensureClauses = {
            "login" = true;
          };
        }) passwordCfgs;
      };

      pwdConfig = passwordCfgs: {
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
            cfgsWithPasswords = builtins.filter (cfg: cfg.passwordFile != null) passwordCfgs;
          in
            if (builtins.length cfgsWithPasswords) == 0 then "" else
              prefix + (lib.concatStrings (map exec cfgsWithPasswords)) + suffix;
      };
    in
      lib.mkMerge (
        [
          (dbConfig cfg.passwords)
          (pwdConfig cfg.passwords)
          (lib.mkIf (!(isNull cfg.tcpIPPort)) (tcpConfig cfg.tcpIPPort))
        ]
      );
}
