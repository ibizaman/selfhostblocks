{
  pkgs,
  lib,
  shb,
  ...
}:
let
  # Only the migration test runs the insecure legacy application to create and restore its fixture.
  # https://github.com/NixOS/nixpkgs/blob/31ecbaca1bdefa45dffc409f0250bd8039ea0010/pkgs/by-name/pi/pinchflat/package.nix#L92-L94
  legacyPinchflat =
    (import pkgs.path {
      inherit (pkgs.stdenv.hostPlatform) system;
      config = pkgs.config // {
        permittedInsecurePackages = [ "pinchflat-2025.9.26" ];
      };
    }).pinchflat;

  commonTestScript = shb.test.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.pinchflat.ssl);
    waitForServices =
      { ... }:
      [
        "pinchflat.service"
        "nginx.service"
      ];
    waitForPorts =
      { node, ... }:
      [
        node.config.shb.pinchflat.port
      ];
  };

  basic =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        ../../modules/blocks/hardcodedsecret.nix
        ../../modules/services/pinchflat.nix
      ];

      test = {
        subdomain = "p";
      };

      shb.pinchflat = {
        enable = true;
        inherit (config.test) subdomain domain;
        mediaDir = "/src/pinchflat";
        timeZone = "America/Los_Angeles";
        secretKeyBase.result = config.shb.hardcodedsecret.secretKeyBase.result;
      };

      systemd.tmpfiles.settings."10-shb-pinchflat" = {
        "/src/pinchflat".d = {
          mode = "0750";
          user = "pinchflat";
          group = "pinchflat";
        };
      };

      # Needed for gitea-runner-local to be able to ping pinchflat.
      networking.hosts = {
        "127.0.0.1" = [ "${config.test.subdomain}.${config.test.domain}" ];
      };

      shb.hardcodedsecret.secretKeyBase = {
        request = config.shb.pinchflat.secretKeyBase.request;
        settings.content = pkgs.lib.strings.replicate 64 "Z";
      };
    };

  clientLogin =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];
      test = {
        subdomain = "p";
      };

      test.login = {
        startUrl = "http://${config.test.fqdn}";
        # There is no login without SSO integration.
        testLoginWith = [
          {
            username = null;
            password = null;
            nextPageExpect = [
              "expect(page.get_by_text('Create a media profile')).to_be_visible()"
            ];
          }
        ];
      };
    };

  https =
    { config, ... }:
    {
      shb.pinchflat = {
        ssl = config.shb.certs.certs.selfsigned.n;
      };
    };

  ldap =
    { config, ... }:
    {
      shb.pinchflat = {
        ldap = {
          enable = true;

          userGroup = "user_group";
        };
      };
    };

  clientLoginSso =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];
      test = {
        subdomain = "p";
      };

      test.login = {
        startUrl = "https://${config.test.fqdn}";
        usernameFieldLabelRegex = "Username";
        passwordFieldLabelRegex = "Password";
        loginButtonNameRegex = "[sS]ign [iI]n";
        testLoginWith = [
          {
            username = "alice";
            password = "NotAlicePassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
            ];
          }
          {
            username = "alice";
            password = "AlicePassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible()"
              "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
              "expect(page.get_by_text('Create a media profile')).to_be_visible()"
            ];
          }
          # Bob, with its admin role only, cannot login into Karakeep because admins do not exist in Karakeep.
          {
            username = "charlie";
            password = "NotCharliePassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
            ];
          }
          {
            username = "charlie";
            password = "CharliePassword";
            nextPageExpect = [
              "expect(page).to_have_url(re.compile('.*/authenticated'))"
            ];
          }
        ];
      };
    };

  sso =
    { config, ... }:
    {
      shb.pinchflat = {
        sso = {
          enable = true;
          authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        };
      };
    };
in
{
  basic = shb.test.runNixOSTest {
    name = "pinchflat_basic";

    nodes.client = {
      imports = [
        clientLogin
      ];
    };
    nodes.server = {
      imports = [
        basic
      ];
    };

    testScript = commonTestScript.access;
  };

  migration = shb.test.runNixOSTest {
    name = "pinchflat_migration";

    nodes.server = {
      imports = [ basic ];
      environment.systemPackages = [ pkgs.sqlite ];

      # The original package is only used to create and restore the test library.
      services.pinchflat.package = legacyPinchflat;
      specialisation.ngx.configuration.services.pinchflat.package = lib.mkForce pkgs.pinchflat-ngx;
    };

    nodes.client = {
      imports = [ clientLogin ];
      test.login.testLoginWith = lib.mkForce [
        {
          username = null;
          password = null;
          nextPageExpect = [
            "expect(page.get_by_role('heading', name='Welcome to Pinchflat-NGX', level=1)).to_be_visible()"
            "expect(page.get_by_role('button', name='Looks good, continue')).to_be_enabled(timeout=60000)"
            "page.get_by_role('button', name='Looks good, continue').click()"
            "expect(page.get_by_role('heading', name='Welcome to Pinchflat-NGX', level=1)).not_to_be_visible()"
            "page.goto('http://p.example.com/sources')"
            "expect(page.get_by_role('link', name='Migration source', exact=True)).to_be_visible()"
          ];
        }
      ];
    };

    testScript =
      { nodes, ... }:
      let
        original = "${legacyPinchflat}/bin/pinchflat";
        ngx = "${pkgs.pinchflat-ngx}/bin/pinchflat";
        system = nodes.server.system.build.toplevel;
        # Derive the fixture through the original application's schemas, as its own tests do:
        # https://github.com/kieraneglin/pinchflat/blob/4f8cba3f9c0edc567687c6a007aaa80b311c6899/test/support/fixtures/sources_fixtures.ex#L18-L43
        fixture = pkgs.writeText "pinchflat-migration-fixture.exs" ''
          {:ok, profile} = Pinchflat.Profiles.create_media_profile(%{
            name: "Migration profile",
            output_path_template: "{{title}}.{{ext}}"
          })
          source = %Pinchflat.Sources.Source{}
            |> Pinchflat.Sources.Source.changeset(%{
              enabled: false,
              collection_name: "Migration channel",
              collection_id: "migration-test-channel",
              collection_type: "channel",
              custom_name: "Migration source",
              original_url: "https://www.youtube.com/@migration-test",
              media_profile_id: profile.id,
              index_frequency_minutes: 60
            }, :pre_insert)
            |> Pinchflat.Repo.insert!()
          path = Path.join(Application.fetch_env!(:pinchflat, :media_directory), "migration.mkv")
          File.cp!("${legacyPinchflat.src}/test/support/files/media.mkv", path)
          {:ok, _media} = Pinchflat.Media.create_media_item(%{
            media_id: "migration-test-video",
            title: "Migration video",
            original_url: "https://www.youtube.com/watch?v=migration-test-video",
            source_id: source.id,
            uploaded_at: ~U[2025-01-01 00:00:00Z],
            media_downloaded_at: ~U[2025-01-02 00:00:00Z],
            media_filepath: path,
            media_size_bytes: File.stat!(path).size,
            livestream: false,
            short_form_content: false
          })
        '';
      in
      ''
        import shlex

        def _rpc(command: str, expression: str) -> str:
            return server.succeed(
                f"runuser -u pinchflat -- {command} rpc {shlex.quote(expression)}"
            ).strip()

        def _library() -> str:
            query = (
                "SELECT id, name, output_path_template FROM media_profiles ORDER BY id;"
                "SELECT id, custom_name, enabled, media_profile_id FROM sources ORDER BY id;"
                "SELECT id, title, source_id, media_filepath, media_size_bytes, media_downloaded_at "
                "FROM media_items ORDER BY id;"
                "SELECT route_token FROM settings;"
            )
            return server.succeed(f"sqlite3 -json /var/lib/pinchflat/db/pinchflat.db {shlex.quote(query)}")

        start_all()
        server.wait_for_unit("pinchflat.service")
        server.wait_for_unit("nginx.service")
        server.wait_for_open_port(8945)

        with subtest("create and back up an original Pinchflat library"):
            _rpc("${original}", 'Code.eval_file("${fixture}")')
            server.succeed("systemctl stop pinchflat.service")
            before = _library()
            media_hash = server.succeed("sha256sum /src/pinchflat/migration.mkv")
            server.succeed("cp -a /var/lib/pinchflat /var/lib/pinchflat-before-ngx")

        with subtest("upgrade preserves the library and holds background work"):
            server.succeed("${system}/specialisation/ngx/bin/switch-to-configuration test")
            server.wait_for_unit("pinchflat.service")
            server.wait_for_open_port(8945)
            assert _library() == before
            assert server.succeed("sha256sum /src/pinchflat/migration.mkv") == media_hash
            assert _rpc("${ngx}", "IO.puts(Pinchflat.LegacyMigration.legacy_migration_pending?())") == "true"
            assert _rpc("${ngx}", "IO.puts(Enum.all?(Oban.config().queues, fn {queue, _} -> Oban.check_queue(queue: queue).paused end))") == "true"

        with subtest("operator review releases the migration hold"):
            client.wait_for_unit("multi-user.target")
            client.succeed("login_playwright")
            assert _rpc("${ngx}", "IO.puts(Pinchflat.LegacyMigration.legacy_migration_pending?())") == "false"
            assert _library() == before

        with subtest("restore the original package and its state backup"):
            server.succeed("systemctl stop pinchflat.service")
            server.succeed("mv /var/lib/pinchflat /var/lib/pinchflat-after-ngx")
            server.succeed("cp -a /var/lib/pinchflat-before-ngx /var/lib/pinchflat")
            server.succeed("${system}/bin/switch-to-configuration test")
            server.wait_for_unit("pinchflat.service")
            server.wait_for_open_port(8945)
            assert _library() == before
            assert server.succeed("sha256sum /src/pinchflat/migration.mkv") == media_hash
            server.succeed("curl --fail http://127.0.0.1:8945/healthcheck")
      '';
  };

  backup = shb.test.runNixOSTest {
    name = "pinchflat_backup";

    nodes.server =
      { config, ... }:
      {
        imports = [
          basic
          (shb.test.backup config.shb.pinchflat.backup)
        ];
      };

    nodes.client = { };

    testScript = commonTestScript.backup;
  };

  https = shb.test.runNixOSTest {
    name = "pinchflat_https";

    nodes.client = {
      imports = [
        clientLogin
      ];
    };
    nodes.server = {
      imports = [
        basic
        shb.test.certs
        https
      ];
    };

    testScript = commonTestScript.access;
  };

  sso = shb.test.runNixOSTest {
    name = "pinchflat_sso";

    nodes.client = {
      imports = [
        clientLoginSso
      ];
    };
    nodes.server =
      { config, pkgs, ... }:
      {
        imports = [
          basic
          shb.test.certs
          https
          shb.test.ldap
          ldap
          (shb.test.sso config.shb.certs.certs.selfsigned.n)
          sso
        ];
      };

    testScript = commonTestScript.access.override {
      redirectSSO = true;
    };
  };
}
