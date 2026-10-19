{ shb, pkgs, ... }:
let
  adminPassword = "AdminPassword";

  runnerWorkflow = pkgs.writeText "runner-smoke.yaml" ''
    on: [push]
    jobs:
      smoke:
        runs-on: native
        steps:
          - run: hello && git --version
  '';

  createRunnerRepository = ''
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

  commonTestScript = shb.test.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.forgejo.ssl);
    waitForServices =
      { ... }:
      [
        "forgejo.service"
        "nginx.service"
        "forgejo-runner-local.service"
      ];
    waitForUnixSocket =
      { node, ... }:
      [
        node.config.services.forgejo.settings.server.HTTP_ADDR
      ];
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
        inherit (config.test) subdomain domain;

        users = {
          "theadmin" = {
            isAdmin = true;
            email = "theadmin@example.com";
            password.result = config.shb.hardcodedsecret.forgejoAdminPassword.result;
          };
          "theuser" = {
            email = "theuser@example.com";
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
    };

  runnerTest =
    { options, ... }:
    {
      imports = [ basic ];
      environment.systemPackages = [
        pkgs.git
        pkgs.jq
      ];
      shb.forgejo.hostPackages = options.shb.forgejo.hostPackages.default ++ [ pkgs.hello ];
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
        startUrl = "http://${config.test.fqdn}/user/login";
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
  runner_recovery = shb.test.runNixOSTest {
    name = "forgejo_runner_recovery";
    nodes.server =
      { config, ... }:
      {
        imports = [
          runnerTest
          (shb.test.backup config.shb.forgejo.backup)
        ];
        # Test-only layout: discard root on reboot, retaining only service data.
        # Use non-default paths to exercise the service's persistence contract.
        services.forgejo = {
          stateDir = "/srv/forgejo";
          customDir = "/srv/forgejo/private";
        };
        # Exercise the pre-switch check for fresh installations as well as upgrades.
        system.switch.enable = true;
        virtualisation.diskImage = null;
        virtualisation.emptyDiskImages = [
          1024
          1024
        ];
        virtualisation.fileSystems = {
          ${config.shb.forgejo.mount.path} = {
            device = "/dev/vda";
            fsType = "ext4";
            autoFormat = true;
          };
          "/var/lib/postgresql" = {
            device = "/dev/vdb";
            fsType = "ext4";
            autoFormat = true;
          };
        };
      };
    testScript =
      { nodes, ... }:
      let
        state = builtins.dirOf nodes.server.services.forgejo-runner.instances.local.secrets.server.connections.default.token_url;
        forgejo = nodes.server.services.forgejo;
        backup = nodes.server.shb.restic.instances.testinstance.result;
      in
      ''
        start_all()
        server.wait_for_unit("forgejo-runner-local.service")
        identity = server.succeed("sha256sum ${state}/uuid ${state}/token")

        with subtest("retry an interrupted registration without changing identity"):
            server.succeed("systemctl stop forgejo-runner-local.service forgejo-runner-initialize.service")
            # Test-only state: registration succeeded but its credentials were not published.
            pending = "${forgejo.customDir}/runner-registration/initializing"
            server.succeed(f"mv ${state} {pending}")
            server.succeed(f"rm {pending}/uuid")
            server.succeed("/run/current-system/bin/switch-to-configuration check")
            server.succeed("systemctl start forgejo-runner-local.service")
            server.wait_for_unit("forgejo-runner-local.service")
            assert server.succeed("sha256sum ${state}/uuid ${state}/token") == identity

        with subtest("runner identity survives loss of the root filesystem"):
            server.succeed("touch /root/disposable")
            server.shutdown()
            server.start()
            server.wait_for_unit("forgejo-runner-local.service")
            server.fail("test -e /root/disposable")
            assert server.succeed("sha256sum ${state}/uuid ${state}/token") == identity

        with subtest("restore runner identity through the Forgejo backup"):
            server.succeed("systemctl stop forgejo-dump.timer forgejo-runner-local.service forgejo-runner-initialize.service forgejo.service")
            server.succeed("systemctl start forgejo-dump.service")
            server.succeed("systemctl start ${backup.backupService}")

            # Lose the credentials and local dump, then recover from the actual backup.
            server.succeed("rm --recursive ${state} ${forgejo.dump.backupDir}")
            server.succeed("${backup.restoreScript} restore latest")
            [archive] = server.succeed("find ${forgejo.dump.backupDir} -name '*.tar.gz'").splitlines()
            server.succeed("mkdir -p /root/restore")
            server.succeed(f"tar --extract --file {archive} --directory /root/restore")
            server.succeed("cp --archive /root/restore/custom/runner-registration/. ${forgejo.customDir}/runner-registration/")
            assert server.succeed("sha256sum ${state}/uuid ${state}/token") == identity
            server.succeed("sudo -u ${forgejo.user} test -r ${state}/token")
            server.fail("sudo -u nobody test -r ${state}/token")
            server.succeed("systemctl start forgejo-runner-local.service")
            server.wait_for_unit("forgejo-runner-local.service")
      ''
      + createRunnerRepository
      + ''
        with subtest("missing saved credentials fail startup without regeneration"):
            server.succeed("systemctl stop forgejo-runner-local.service forgejo-runner-initialize.service")
            server.succeed("rm ${state}/token")
            server.fail("systemctl start forgejo-runner-local.service")
            server.fail("test -e ${state}/token")
      '';
  };

  runner_migration = shb.test.runNixOSTest {
    name = "forgejo_runner_migration";
    nodes.server = {
      imports = [
        runnerTest
        ./forgejo/legacy-runner.nix
      ];
      specialisation.native.configuration.shb.forgejo.localActionRunner = true;
    };
    testScript =
      { nodes, ... }:
      let
        system = nodes.server.system.build.toplevel;
      in
      ''
        start_all()
        server.wait_for_unit("gitea-runner-local.service")
        legacy = "/var/lib/gitea-runner/local/.runner"
        state = "${nodes.server.services.forgejo.customDir}/runner-registration/initialized"
        native_system = server.succeed("readlink -f ${system}/specialisation/native").strip()
        migrate = f"{native_system}/sw/bin/shb-forgejo-runner-migrate"
        legacy_hash = server.succeed(f"sha256sum {legacy}")
        uuid = server.succeed(f"jq --raw-output .uuid {legacy}").strip()

        with subtest("legacy installations require an explicit migration"):
            server.fail(migrate)  # The legacy runner must be stopped first.
            current_system = server.succeed("readlink /run/current-system")
            runner_started = server.succeed("systemctl show --property=ExecMainStartTimestampMonotonic --value gitea-runner-local.service")
            output = server.fail("${system}/specialisation/native/bin/switch-to-configuration test 2>&1")
            assert migrate in output
            server.succeed("systemctl is-active --quiet gitea-runner-local.service")
            assert server.succeed("systemctl show --property=ExecMainStartTimestampMonotonic --value gitea-runner-local.service") == runner_started
            assert server.succeed("readlink /run/current-system") == current_system
            server.fail(f"test -e {state}")
            assert server.succeed(f"sha256sum {legacy}") == legacy_hash

        with subtest("failed migration does not record completion and can be retried"):
            server.succeed("systemctl stop gitea-runner-local.service")
            server.succeed(f"cp --preserve=mode,ownership {legacy} {legacy}.saved")
            server.succeed(f"printf '{{}}' > {legacy}")
            server.fail(migrate)
            server.fail(f"test -e {state}")
            server.succeed(f"mv {legacy}.saved {legacy}")
            server.succeed(migrate)
            server.fail(migrate)

        with subtest("migrate the registered legacy runner"):
            server.succeed("${system}/specialisation/native/bin/switch-to-configuration test")
            server.wait_for_unit("forgejo-runner-local.service")
            server.fail("systemctl is-active --quiet gitea-runner-local.service")
            server.succeed(f"jq --join-output .token {legacy} | cmp - {state}/token")
            assert server.succeed(f"sha256sum {legacy}") == legacy_hash
            assert server.succeed(f"cat {state}/uuid").strip() == uuid
            identity = server.succeed(f"sha256sum {state}/uuid {state}/token")
            server.fail(f"sudo -u nobody test -r {state}/token")
            server.succeed(f"sudo -u forgejo test -r {state}/token")
      ''
      + createRunnerRepository
      + ''
        with subtest("rollback and migrate again without re-registration"):
            server.succeed("${system}/bin/switch-to-configuration test")
            server.wait_for_unit("gitea-runner-local.service")
            server.fail("systemctl is-active --quiet forgejo-runner-local.service")
            assert server.succeed(f"sha256sum {legacy}") == legacy_hash
            server.succeed("${system}/specialisation/native/bin/switch-to-configuration test")
            server.wait_for_unit("forgejo-runner-local.service")
            assert server.succeed(f"sha256sum {state}/uuid {state}/token") == identity
            server.succeed("git -C /root/runner-test commit --allow-empty --message 'Run after rollback'")
            server.succeed("git -C /root/runner-test push origin main")
            server.wait_until_succeeds(api + " " + repo + "/actions/tasks | jq --exit-status '(.workflow_runs | length) == 2 and all(.workflow_runs[]; .status == \"success\")'", timeout=180)
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

    nodes.client = { };

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
