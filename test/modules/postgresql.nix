{ lib, ... }:
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
          ../../modules/blocks/postgresql.nix
          m
        ];
      }).config;
    in {
      inherit (cfg) systemd services;
    };

  commonSettings = {
    # idle_in_transaction_session_timeout = "30s";
    # idle_session_timeout = "30s";
    # track_io_timing = "true";
  };
in
{
  testPostgresNoOptions = {
    expected = {
      services.postgresql = {
        enable = false;
        ensureUsers = [];
        ensureDatabases = [];
        settings = commonSettings;
      };
      systemd.services.postgresql.postStart = "";
    };
    expr = testConfig {};
  };

  testPostgresManualOptions = {
    expected = {
      services.postgresql = {
        enable = true;
        ensureUsers = [];
        ensureDatabases = [];
        settings = commonSettings;
      };
      systemd.services.postgresql.postStart = "";
    };
    expr = testConfig {
      services.postgresql.enable = true;
    };
  };

  testPostgresOneWithoutPassword = {
    expected = {
      services.postgresql = {
        enable = true;
        ensureUsers = [{
          name = "myuser";
          ensureDBOwnership = true;
          ensureClauses = {
            "login" = true;
          };
        }];
        ensureDatabases = ["mydatabase"];
        settings = commonSettings;
      };
      systemd.services.postgresql.postStart = "";
    };
    expr = testConfig {
      shb.postgresql.ensures = [
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
          ensureDBOwnership = true;
          ensureClauses = {
            "login" = true;
          };
        }];
        ensureDatabases = ["mydatabase"];
        settings = commonSettings;
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
      shb.postgresql.ensures = [
        {
          username = "myuser";
          database = "mydatabase";
          passwordFile = "/my/file";
        }
      ];
    };
  };

  testPostgresTwoNoPassword = {
    expected = {
      services.postgresql = {
        enable = true;
        ensureUsers = [
          {
            name = "user1";
            ensureDBOwnership = true;
            ensureClauses = {
              "login" = true;
            };
          }
          {
            name = "user2";
            ensureDBOwnership = true;
            ensureClauses = {
              "login" = true;
            };
          }
        ];
        ensureDatabases = ["db1" "db2"];
        settings = commonSettings;
      };
      systemd.services.postgresql.postStart = "";
    };
    expr = testConfig {
      shb.postgresql.ensures = [
        {
          username = "user1";
          database = "db1";
        }
        {
          username = "user2";
          database = "db2";
        }
      ];
    };
  };

  testPostgresTwoWithPassword = {
    expected = {
      services.postgresql = {
        enable = true;
        ensureUsers = [
          {
            name = "user1";
            ensureDBOwnership = true;
            ensureClauses = {
              "login" = true;
            };
          }
          {
            name = "user2";
            ensureDBOwnership = true;
            ensureClauses = {
              "login" = true;
            };
          }
        ];
        ensureDatabases = ["db1" "db2"];
        settings = commonSettings;
      };
      systemd.services.postgresql.postStart = ''
      $PSQL -tA <<'EOF'
        DO $$
        DECLARE password TEXT;
        BEGIN
      password := trim(both from replace(pg_read_file('/file/user1'), E'\n', '''));
      EXECUTE format('ALTER ROLE user1 WITH PASSWORD '''%s''';', password);
      password := trim(both from replace(pg_read_file('/file/user2'), E'\n', '''));
      EXECUTE format('ALTER ROLE user2 WITH PASSWORD '''%s''';', password);
        END $$;
      EOF
      '';
    };
    expr = testConfig {
      shb.postgresql.ensures = [
        {
          username = "user1";
          database = "db1";
          passwordFile = "/file/user1";
        }
        {
          username = "user2";
          database = "db2";
          passwordFile = "/file/user2";
        }
      ];
    };
  };

  testPostgresTwoWithMixedPassword = {
    expected = {
      services.postgresql = {
        enable = true;
        ensureUsers = [
          {
            name = "user1";
            ensureDBOwnership = true;
            ensureClauses = {
              "login" = true;
            };
          }
          {
            name = "user2";
            ensureDBOwnership = true;
            ensureClauses = {
              "login" = true;
            };
          }
        ];
        ensureDatabases = ["db1" "db2"];
        settings = commonSettings;
      };
      systemd.services.postgresql.postStart = ''
      $PSQL -tA <<'EOF'
        DO $$
        DECLARE password TEXT;
        BEGIN
      password := trim(both from replace(pg_read_file('/file/user2'), E'\n', '''));
      EXECUTE format('ALTER ROLE user2 WITH PASSWORD '''%s''';', password);
        END $$;
      EOF
      '';
    };
    expr = testConfig {
      shb.postgresql.ensures = [
        {
          username = "user1";
          database = "db1";
        }
        {
          username = "user2";
          database = "db2";
          passwordFile = "/file/user2";
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
        settings = commonSettings;
        
        enableTCPIP = true;
        authentication = ''
          #type database DBuser origin-address auth-method
          local all      all    peer
          # ipv4
          host  all      all    127.0.0.1/32   password
          # ipv6
          host  all      all    ::1/128        password
        '';
      };
      systemd.services.postgresql.postStart = "";
    };
    expr = testConfig {
      shb.postgresql.enableTCPIP = true;
    };
  };
}
