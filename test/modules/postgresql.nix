{ lib }:
let
  anyOpt = default: lib.mkOption {
    type = lib.types.anything;
    inherit default;
  };

  testConfig = m:
    let
      cfg = (lib.evalModules {
        modules = [
          {
            options = {
              services = anyOpt {};
              systemd = anyOpt {};
            };
          }
          ../../modules/postgresql.nix
          m
        ];
      }).config;
    in {
      inherit (cfg) systemd services;
    };
in
{
  testPostgresNoOptions = {
    expected = {
      services.postgresql = {
        enable = false;
        ensureUsers = [];
        ensureDatabases = [];
      };
      systemd.services.postgresql.postStart = "";
    };
    expr = testConfig {};
  };

  testPostgresOneWithoutPassword = {
    expected = {
      services.postgresql = {
        enable = true;
        ensureUsers = [{
          name = "myuser";
          ensurePermissions = {
            "DATABASE mydatabase" = "ALL PRIVILEGES";
          };
          ensureClauses = {
            "login" = true;
          };
        }];
        ensureDatabases = ["mydatabase"];
      };
      systemd.services.postgresql.postStart = "";
    };
    expr = testConfig {
      shb.postgresql.passwords = [
        {
          username = "myuser";
          database = "mydatabase";
        }
      ];
    };
  };

  testPostgresOneWithPassword = {
    expected = {
      services.postgresql = {
        enable = true;
        ensureUsers = [{
          name = "myuser";
          ensurePermissions = {
            "DATABASE mydatabase" = "ALL PRIVILEGES";
          };
          ensureClauses = {
            "login" = true;
          };
        }];
        ensureDatabases = ["mydatabase"];
      };
      systemd.services.postgresql.postStart = ''
      $PSQL -tA <<'EOF'
        DO $$
        DECLARE password TEXT;
        BEGIN
          password := trim(both from replace(pg_read_file('/my/file'), E'\n', '''));
          EXECUTE format('ALTER ROLE myuser WITH PASSWORD '''%s''';', password);
        END $$;
      EOF
      '';
    };
    expr = testConfig {
      shb.postgresql.passwords = [
        {
          username = "myuser";
          database = "mydatabase";
          passwordFile = "/my/file";
        }
      ];
    };
  };

  testPostgresTCPIP = {
    expected = {
      services.postgresql = {
        enable = false;
        ensureUsers = [];
        ensureDatabases = [];
        
        enableTCPIP = true;
        port = 1234;
        authentication = ''
          #type database DBuser origin-address auth-method
          # ipv4
          host  all      all     127.0.0.1/32   trust
          # ipv6
          host all       all     ::1/128        trust
        '';
      };
      systemd.services.postgresql.postStart = "";
    };
    expr = testConfig {
      shb.postgresql.tcpIPPort = 1234;
    };
  };
}
