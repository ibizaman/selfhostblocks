{
  shb,
  pkgs,
  lib,
  ...
}:
let
  adminPassword = "AdminPassword";

  # Public test credentials from Forgejo's offline registration example.
  # https://forgejo.org/docs/v15.0/admin/actions/registration/#offline-registration
  runnerIdentity = {
    uuid = "37633331-3539-3165-3862-363732323561";
    token = "7c31591e8b67225a116d4a4519ea8e507e08f71f";
  };

  runnerWorkflow = pkgs.writeText "runner-smoke.yaml" ''
    on: [push]
    jobs:
      smoke:
        runs-on: native
        steps:
          - run: hello && git --version
  '';

  commonTestScript = shb.test.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.forgejo.ssl);
    waitForServices =
      { ... }:
      [
        "forgejo.service"
        "nginx.service"
      ];
    waitForUnixSocket =
      { node, ... }:
      [
        node.config.services.forgejo.settings.server.HTTP_ADDR
      ];
    preLoginScript =
      { node, proto_fqdn, ... }:
      ''
        http_repository = json.loads(server.succeed("""curl --fail --silent --show-error --unix-socket ${node.config.services.forgejo.settings.server.HTTP_ADDR} --user theadmin:${adminPassword} --json '{"name":"test-only-http-url"}' http://localhost/api/v1/user/repos"""))
        assert http_repository["clone_url"] == "${proto_fqdn}/theadmin/test-only-http-url.git", http_repository["clone_url"]
        with subtest("SMTP settings and credentials are installed"):
            import configparser
            settings = configparser.ConfigParser(interpolation=None, allow_unnamed_section=True)
            settings.read_string(server.succeed("cat /var/lib/forgejo/custom/conf/app.ini"))
            assert settings["mailer"]["SMTP_ADDR"] == "localhost"
            assert settings["mailer"]["SMTP_PORT"] == "587"
            assert settings["mailer"]["PASSWD"] == "test-only-smtp-password"
        server.succeed("systemctl restart forgejo.service")
      ''
      + lib.optionalString node.config.shb.forgejo.sso.enable ''
        from urllib import parse
        for restart in (False, True):
            if restart:
                server.succeed("systemctl restart forgejo.service")
            redirect = client.wait_until_succeeds("curl --fail --silent --show-error --resolve ${node.config.test.fqdn}:443:192.168.1.2 --output /dev/null --write-out '%{redirect_url}' ${proto_fqdn}/user/oauth2/SHB-Authelia")
            assert parse.parse_qs(parse.urlsplit(redirect).query)["client_id"] == ["test-only-forgejo"]
      '';
  };

  basic =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        ../../modules/blocks/hardcodedsecret.nix
        ../../modules/services/forgejo.nix
      ];

      test = {
        subdomain = "f";
      };

      shb.forgejo = {
        enable = true;
        localActionRunner = lib.mkDefault false;
        inherit (config.test) subdomain domain;
        smtp = {
          from_address = "forgejo@example.com";
          host = "localhost";
          port = 587;
          username = "test-only-smtp";
          password.result = config.shb.hardcodedsecret.forgejoSmtpPassword.result;
        };

        users = {
          "theadmin" = {
            isAdmin = true;
            email = "theuser@example.com"; # Test-only overlap with the other username.
            password.result = config.shb.hardcodedsecret.forgejoAdminPassword.result;
          };
          "theuser" = {
            email = "theadmin@example.com";
            password.result = config.shb.hardcodedsecret.forgejoUserPassword.result;
          };
        };
        databasePassword.result = config.shb.hardcodedsecret.forgejoDatabasePassword.result;
      };

      # Needed for the local runner to be able to reach Forgejo.
      networking.hosts = {
        "127.0.0.1" = [ "${config.test.subdomain}.${config.test.domain}" ];
      };

      shb.hardcodedsecret.forgejoAdminPassword = {
        request = config.shb.forgejo.users."theadmin".password.request;
        settings.content = adminPassword;
      };

      shb.hardcodedsecret.forgejoUserPassword = {
        request = config.shb.forgejo.users."theuser".password.request;
        settings.content = "userPassword";
      };

      shb.hardcodedsecret.forgejoDatabasePassword = {
        request = config.shb.forgejo.databasePassword.request;
        settings.content = "databasePassword";
      };
      shb.hardcodedsecret.forgejoSmtpPassword = {
        request = config.shb.forgejo.smtp.password.request;
        settings.content = "test-only-smtp-password";
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
        subdomain = "f";
      };

      test.login = {
        startUrl = "${config.test.proto}://${config.test.fqdn}/user/login";
        usernameFieldLabelRegex = "Username or email address";
        passwordFieldLabelRegex = "Password";
        loginButtonNameRegex = "[sS]ign [iI]n";
        testLoginWith = [
          {
            username = "theadmin";
            password = adminPassword + "oops";
            nextPageExpect = [
              "expect(page.get_by_text('Username or password is incorrect.')).to_be_visible()"
            ];
          }
          {
            username = "theadmin";
            password = adminPassword;
            nextPageExpect = [
              "expect(page.get_by_text('Username or password is incorrect.')).not_to_be_visible()"
              "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
              "expect(page).to_have_title(re.compile('Dashboard'))"
              "assert any(cookie['name'] == 'session' and cookie['secure'] == '${config.test.login.startUrl}'.startswith('https://') for cookie in page.context.cookies('${config.test.login.startUrl}'))"
            ];
          }
          {
            username = "theuser";
            password = "userPasswordOops";
            nextPageExpect = [
              "expect(page.get_by_text('Username or password is incorrect.')).to_be_visible()"
            ];
          }
          {
            username = "theuser";
            password = "userPassword";
            nextPageExpect = [
              "expect(page.get_by_text('Username or password is incorrect.')).not_to_be_visible()"
              "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
              "expect(page).to_have_title(re.compile('Dashboard'))"
            ];
          }
        ];
      };
    };

  https =
    { config, ... }:
    {
      shb.forgejo = {
        ssl = config.shb.certs.certs.selfsigned.n;
      };
    };

  ldap =
    { config, ... }:
    {
      shb.forgejo = {
        ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.lldap.ldapPort;
          dcdomain = config.shb.lldap.dcdomain;
          adminPassword.result = config.shb.hardcodedsecret.forgejoLdapUserPassword.result;
          waitForSystemdServices = [ "lldap.service" ];

          userGroup = "user_group";
          adminGroup = "admin_group";
        };
      };

      shb.hardcodedsecret.forgejoLdapUserPassword = {
        request = config.shb.forgejo.ldap.adminPassword.request;
        settings.content = "ldapUserPassword";
      };
    };

  sso =
    { config, ... }:
    {
      shb.forgejo = {
        sso = {
          enable = true;
          clientID = "test-only-forgejo";
          endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          sharedSecret.result = config.shb.hardcodedsecret.forgejoSSOPassword.result;
          sharedSecretForAuthelia.result = config.shb.hardcodedsecret.forgejoSSOPasswordAuthelia.result;
        };
      };

      shb.hardcodedsecret.forgejoSSOPassword = {
        request = config.shb.forgejo.sso.sharedSecret.request;
        settings.content = "ssoPassword";
      };

      shb.hardcodedsecret.forgejoSSOPasswordAuthelia = {
        request = config.shb.forgejo.sso.sharedSecretForAuthelia.request;
        settings.content = "ssoPassword";
      };
    };
in
{
  runner = shb.test.runNixOSTest {
    name = "forgejo_runner";
    nodes.server =
      { config, options, ... }:
      {
        imports = [ basic ];
        environment.systemPackages = [
          pkgs.git
          pkgs.jq
        ];
        shb.forgejo = {
          localActionRunner = true;
          runner = {
            inherit (runnerIdentity) uuid;
            token.result = config.shb.hardcodedsecret.runnerToken.result;
          };
          hostPackages = options.shb.forgejo.hostPackages.default ++ [ pkgs.hello ];
        };
        shb.hardcodedsecret.runnerToken = {
          request = config.shb.forgejo.runner.token.request;
          settings.content = runnerIdentity.token;
        };
        # The test registers the fixture before starting its runner.
        systemd.services.forgejo-runner-local.wantedBy = lib.mkForce [ ];
      };
    testScript =
      { nodes, ... }:
      let
        forgejo = nodes.server.services.forgejo;
        runner = nodes.server.shb.forgejo.runner;
      in
      ''
        start_all()
        server.wait_for_unit("forgejo.service")
        server.wait_for_unit("nginx.service")
        server.wait_for_open_unix_socket("${forgejo.settings.server.HTTP_ADDR}")
        with subtest("connect with operator-provided credentials"):
            uuid = server.succeed(
                "sudo -u ${forgejo.user} env FORGEJO_WORK_DIR=${forgejo.stateDir} FORGEJO_CUSTOM=${forgejo.customDir}"
                + " ${lib.getExe forgejo.package} forgejo-cli actions register --name local --secret-stdin=true"
                + " < ${runner.token.result.path}"
            ).strip()
            assert uuid == "${runner.uuid}"
            server.succeed("systemctl start forgejo-runner-local.service")
            server.wait_for_unit("forgejo-runner-local.service")
            server.fail("sudo -u nobody test -r ${runner.token.result.path}")

        # Test-only API credentials. The workflow uses no external actions or network downloads.
        api = "curl --fail --silent --show-error --user theadmin:${adminPassword}"
        repo = "http://f.example.com/api/v1/repos/theadmin/runner-test"
        with subtest("execute a workflow with the saved identity and configured host packages"):
            server.succeed(api + " --json '{\"name\":\"runner-test\",\"private\":false}' http://f.example.com/api/v1/user/repos")
            server.succeed(api + " --request PATCH --json '{\"has_actions\":true}' " + repo)
            server.succeed("git init --initial-branch=main /root/runner-test")
            server.succeed("git -C /root/runner-test config user.email runner-test@example.com")
            server.succeed("git -C /root/runner-test config user.name 'Runner test'")
            server.succeed("mkdir -p /root/runner-test/.forgejo/workflows")
            server.succeed("cp ${runnerWorkflow} /root/runner-test/.forgejo/workflows/smoke.yaml")
            server.succeed("git -C /root/runner-test add .")
            server.succeed("git -C /root/runner-test commit --message 'Run smoke workflow'")
            server.succeed("git -C /root/runner-test remote add origin http://theadmin:${adminPassword}@f.example.com/theadmin/runner-test.git")
            server.succeed("git -C /root/runner-test push origin main")
            server.wait_until_succeeds(api + " " + repo + "/actions/tasks | jq --exit-status '.workflow_runs[0].status == \"success\"'", timeout=180)

      '';
  };

  basic = shb.test.runNixOSTest {
    name = "forgejo_basic";

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

  backup = shb.test.runNixOSTest {
    name = "forgejo_backup";

    nodes.server =
      { config, ... }:
      {
        imports = [
          basic
          (shb.test.backup config.shb.forgejo.backup)
        ];
      };

    nodes.client = { };

    testScript = commonTestScript.backup;
  };

  https = shb.test.runNixOSTest {
    name = "forgejo_https";

    nodes.server = {
      imports = [
        basic
        shb.test.certs
        https
      ];
    };

    nodes.client = {
      imports = [ clientLogin ];
      test.hasSSL = true;
    };

    testScript = commonTestScript.access;
  };

  ldap = shb.test.runNixOSTest {
    name = "forgejo_ldap";

    nodes.server = {
      imports = [
        basic
        shb.test.ldap
        ldap
      ];
    };

    nodes.client = {
      imports = [
        (
          { config, ... }:
          {
            imports = [
              shb.test.baseModule
              shb.test.clientLoginModule
            ];

            test = {
              subdomain = "f";
            };

            test.login = {
              startUrl = "http://${config.test.fqdn}/user/login";
              usernameFieldLabelRegex = "Username or email address";
              passwordFieldLabelRegex = "Password";
              loginButtonNameRegex = "[sS]ign [iI]n";
              testLoginWith = [
                {
                  username = "alice";
                  password = "NotAlicePassword";
                  nextPageExpect = [
                    "expect(page.get_by_text('Username or password is incorrect.')).to_be_visible()"
                  ];
                }
                {
                  username = "alice";
                  password = "AlicePassword";
                  nextPageExpect = [
                    "expect(page.get_by_text('Username or password is incorrect.')).not_to_be_visible()"
                    "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
                    "expect(page).to_have_title(re.compile('Dashboard'))"
                  ];
                }
                {
                  username = "bob";
                  password = "NotBobPassword";
                  nextPageExpect = [
                    "expect(page.get_by_text('Username or password is incorrect.')).to_be_visible()"
                  ];
                }
                {
                  username = "bob";
                  password = "BobPassword";
                  nextPageExpect = [
                    "expect(page.get_by_text('Username or password is incorrect.')).not_to_be_visible()"
                    "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
                    "expect(page).to_have_title(re.compile('Dashboard'))"
                  ];
                }
                {
                  username = "charlie";
                  password = "NotCharliePassword";
                  nextPageExpect = [
                    "expect(page.get_by_text('Username or password is incorrect.')).to_be_visible()"
                  ];
                }
                {
                  username = "charlie";
                  password = "CharliePassword";
                  nextPageExpect = [
                    "expect(page.get_by_text('Username or password is incorrect.')).to_be_visible()"
                  ];
                }
              ];
            };
          }
        )
      ];
    };

    testScript = commonTestScript.access;
  };

  sso = shb.test.runNixOSTest {
    name = "forgejo_sso";

    nodes.server =
      { config, pkgs, ... }:
      {
        imports = [
          basic
          shb.test.certs
          https
          ldap
          shb.test.ldap
          (shb.test.sso config.shb.certs.certs.selfsigned.n)
          sso
        ];
      };

    nodes.client = { };

    testScript = commonTestScript.access;
  };
}
