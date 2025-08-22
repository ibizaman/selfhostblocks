{ pkgs, lib }:
let
  inherit (lib) hasAttr mkOption optionalString;
  inherit (lib.types) bool enum listOf nullOr submodule str;

  baseImports = {
    imports = [
      (pkgs.path + "/nixos/modules/profiles/headless.nix")
      (pkgs.path + "/nixos/modules/profiles/qemu-guest.nix")
    ];
  };

  accessScript = lib.makeOverridable ({
    hasSSL
    , waitForServices ? s: []
    , waitForPorts ? p: []
    , waitForUnixSocket ? u: []
    , waitForUrls ? u: []
    , extraScript ? {...}: ""
    , redirectSSO ? false
  }: { nodes, ... }:
    let
      cfg = nodes.server.test;

      fqdn = "${cfg.subdomain}.${cfg.domain}";
      proto_fqdn = if hasSSL args then "https://${fqdn}" else "http://${fqdn}";

      args = {
        node.name = "server";
        node.config = nodes.server;
        inherit fqdn proto_fqdn;
      };
    in
    ''
    import json
    import os
    import pathlib

    start_all()

    def curl(target, format, endpoint, data="", extra=""):
        cmd = ("curl --show-error --location"
              + " --cookie-jar cookie.txt"
              + " --cookie cookie.txt"
              + " --connect-to ${fqdn}:443:server:443"
              + " --connect-to ${fqdn}:80:server:80"
              # Client must be able to resolve talking to auth server
              + " --connect-to auth.${cfg.domain}:443:server:443"
              + (f" --data '{data}'" if data != "" else "")
              + (f" --silent --output /dev/null --write-out '{format}'" if format != "" else "")
              + (f" {extra}" if extra != "" else "")
              + f" {endpoint}")
        print(cmd)
        _, r = target.execute(cmd)
        print(r)
        try:
            return json.loads(r)
        except:
            return r

    def unline_with(j, s):
        return j.join((x.strip() for x in s.split("\n")))
    ''
    + lib.strings.concatMapStrings (s: ''server.wait_for_unit("${s}")'' + "\n") (
      waitForServices args
      ++ (lib.optionals redirectSSO [ "authelia-auth.${cfg.domain}.service" ])
    )
    + lib.strings.concatMapStrings (p: ''server.wait_for_open_port(${toString p})'' + "\n") (
      waitForPorts args
      # TODO: when the SSO block exists, replace this hardcoded port.
      ++ (lib.optionals redirectSSO [ 9091 /* nodes.server.services.authelia.instances."auth.${domain}".settings.server.port */ ] )
    )
    + lib.strings.concatMapStrings (u: ''server.wait_for_open_unix_socket("${u}")'' + "\n") (waitForUnixSocket args)
    + ''
    if ${if hasSSL args then "True" else "False"}:
        server.copy_from_vm("/etc/ssl/certs/ca-certificates.crt")
        client.succeed("rm -r /etc/ssl/certs")
        client.copy_from_host(str(pathlib.Path(os.environ.get("out", os.getcwd())) / "ca-certificates.crt"), "/etc/ssl/certs/ca-certificates.crt")

    ''
    # Making a curl request to an URL needs to happen after we copied the certificates over,
    # otherwise curl will not be able to verify the "legitimacy of the server".
    + lib.strings.concatMapStrings (u: ''
        import time

        done = False
        count = 15
        while not done and count > 0:
            response = curl(client, """{"code":%{response_code}}""", "${u}")
            time.sleep(5)
            count -= 1
            if isinstance(response, dict):
                done = response.get('code') == 200
        if not done:
            raise Exception(f"Response was never 200, got last: {response}")
      '' + "\n") (
      waitForUrls args
    )
    + (if (! redirectSSO) then ''
    with subtest("access"):
        response = curl(client, """{"code":%{response_code}}""", "${proto_fqdn}")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")
    '' else ''
    with subtest("unauthenticated access is not granted"):
        response = curl(client, """{"code":%{response_code},"auth_host":"%{urle.host}","auth_query":"%{urle.query}","all":%{json}}""", "${proto_fqdn}")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")
        if response['auth_host'] != "auth.${cfg.domain}":
            raise Exception(f"auth host should be auth.${cfg.domain} but is {response['auth_host']}")
        if response['auth_query'] != "rd=${proto_fqdn}/":
            raise Exception(f"auth query should be rd=${proto_fqdn}/ but is {response['auth_query']}")
    '')
    + (let
      script = extraScript args;
    in
      lib.optionalString (script != "") script)
    + (optionalString (hasAttr "test" nodes.server && hasAttr "login" nodes.server.test) ''
    with subtest("Login from server"):
        code, logs = server.execute("login_playwright")
        print(logs)
        try:
            server.copy_from_vm("trace")
        except:
            print("No trace found on server")
        if code != 0:
            raise Exception("login_playwright did not succeed")
    '')
    + (optionalString (hasAttr "test" nodes.client && hasAttr "login" nodes.client.test) ''
    with subtest("Login from client"):
        code, logs = client.execute("login_playwright")
        print(logs)
        try:
            client.copy_from_vm("trace")
        except:
            print("No trace found on client")
        if code != 0:
            raise Exception("login_playwright did not succeed")
    '')
  );

  backupScript = args: (accessScript args).override {
    extraScript = { proto_fqdn, ... }: ''
    with subtest("backup"):
        server.succeed("systemctl start restic-backups-testinstance_opt_repos_A")
    '';
  };
in
{
  inherit baseImports accessScript;

  mkScripts = args:
    {
      access = accessScript args;
      backup = backupScript args;
    };

  baseModule = { config, ... }: {
    options.test = {
      domain = mkOption {
        type = str;
        default = "example.com";
      };
      subdomain = mkOption {
        type = str;
      };
      fqdn = mkOption {
        type = str;
        readOnly = true;
        default = "${config.test.subdomain}.${config.test.domain}";
      };
      hasSSL = mkOption {
        type = bool;
        default = false;
      };
      proto = mkOption {
        type = str;
        readOnly = true;
        default = if config.test.hasSSL then "https" else "http";
      };
      proto_fqdn = mkOption {
        type = str;
        readOnly = true;
        default = "${config.test.proto}://${config.test.fqdn}";
      };
    };
    imports = [
      baseImports
      ../modules/blocks/authelia.nix
      ../modules/blocks/hardcodedsecret.nix
      ../modules/blocks/mitmdump.nix
      ../modules/blocks/nginx.nix
      ../modules/blocks/postgresql.nix
    ];
    config = {
      # HTTP(s) server port.
      networking.firewall.allowedTCPPorts = [ 80 443 ];
      shb.nginx.accessLog = true;

      networking.hosts = {
        "192.168.1.2" = [ config.test.fqdn ];
      };
    };
  };

  clientLoginModule = { config, pkgs, ... }: let
    cfg = config.test.login;
  in {
    options.test.login = {
      browser = mkOption {
        type = enum [ "firefox" "chromium" "webkit" ];
        default = "firefox";
      };
      usernameFieldLabelRegex = mkOption {
        type = str;
        default = "[Uu]sername";
      };
      usernameFieldSelector = mkOption {
        type = str;
        default = "get_by_label(re.compile('${cfg.usernameFieldLabelRegex}'))";
      };
      passwordFieldLabelRegex = mkOption {
        type = str;
        default = "[Pp]assword";
      };
      passwordFieldSelector = mkOption {
        type = str;
        default = "get_by_label(re.compile('${cfg.passwordFieldLabelRegex}'))";
      };
      loginButtonNameRegex = mkOption {
        type = str;
        default = "[Ll]ogin";
      };
      testLoginWith = mkOption {
        type = listOf (submodule {
          options = {
            username = mkOption {
              type = nullOr str;
              default = null;
            };
            password = mkOption {
              type = nullOr str;
              default = null;
            };
            nextPageExpect = mkOption {
              type = listOf str;
            };
          };
        });
      };
      startUrl = mkOption {
        type = str;
        default = "http://${config.test.fqdn}";
      };
      beforeHook = mkOption {
        type = str;
        default = "";
      };
    };
    config = {
      networking.hosts = {
        "192.168.1.2" = [ config.test.fqdn ];
      };

      environment.variables = {
        PLAYWRIGHT_BROWSERS_PATH = pkgs.playwright-driver.browsers;
      };

      environment.systemPackages = [
        (pkgs.writers.writePython3Bin "login_playwright"
          {
            libraries = [ pkgs.python3Packages.playwright ];
            flakeIgnore = [ "F401" "E501" ];
          }
          (let
            testCfg = pkgs.writeText "users.json" (builtins.toJSON cfg);
          in ''
            import json
            import re
            import sys
            from playwright.sync_api import expect
            from playwright.sync_api import sync_playwright


            browsers = {
                "chromium": {'args': ["--headless", "--disable-gpu"], 'channel': 'chromium'},
                "firefox": {'args': ["--reporter", "html"]},
                "webkit": {},
            }

            with open("${testCfg}") as f:
                testCfg = json.load(f)

            browser_name = testCfg['browser']
            browser_args = browsers.get(browser_name)
            print(f"Running test on {browser_name} {' '.join(browser_args)}")

            with sync_playwright() as p:
                browser = getattr(p, browser_name).launch(**browser_args)

                for i, u in enumerate(testCfg["testLoginWith"]):
                    print(f"Testing for user {u['username']} and password {u['password']}")

                    context = browser.new_context(ignore_https_errors=True)
                    context.set_default_navigation_timeout(2 * 60 * 1000)
                    context.tracing.start(screenshots=True, snapshots=True, sources=True)
                    try:
                        page = context.new_page()
                        print(f"Going to {testCfg['startUrl']}")
                        page.goto(testCfg['startUrl'])

                        if testCfg.get("beforeHook") is not None:
                            exec(testCfg.get("beforeHook"))
      
                        if u['username'] is not None:
                            print(f"Filling field username with {u['username']}")
                            page.${cfg.usernameFieldSelector}.fill(u['username'])
                        if u['password'] is not None:
                            print(f"Filling field password with {u['password']}")
                            page.${cfg.passwordFieldSelector}.fill(u['password'])

                        # Assumes we don't need to login, so skip this.
                        if u['username'] is not None or u['password'] is not None:
                            print(f"Clicking button {testCfg['loginButtonNameRegex']}")
                            page.get_by_role("button", name=re.compile(testCfg['loginButtonNameRegex'])).click()

                        for line in u['nextPageExpect']:
                            print(f"Running: {line}")
                            print(f"Page has title: {page.title()}")
                            exec(line)
                    finally:
                        print(f'Saving trace at trace/{i}.zip')
                        context.tracing.stop(path=f"trace/{i}.zip")

                browser.close()
          '')
        )
      ];
    };
  };

  backup = backupOption: { config, ... }: {
    imports = [
      ../modules/blocks/restic.nix
    ];
    shb.restic.instances."testinstance" = {
      request = backupOption.request;
      settings = {
        enable = true;
        passphrase.result = config.shb.hardcodedsecret.backupPassphrase.result;
        repository = {
          path = "/opt/repos/A";
          timerConfig = {
            OnCalendar = "00:00:00";
            RandomizedDelaySec = "5h";
          };
        };
      };
    };
    shb.hardcodedsecret.backupPassphrase = {
      request = config.shb.restic.instances."testinstance".settings.passphrase.request;
      settings.content = "PassPhrase";
    };
  };

  certs = { config, ... }: {
    imports = [
      ../modules/blocks/ssl.nix
    ];

    shb.certs = {
      cas.selfsigned.myca = {
        name = "My CA";
      };
      certs.selfsigned = {
        n = {
          ca = config.shb.certs.cas.selfsigned.myca;
          domain = "*.${config.test.domain}";
          group = "nginx";
        };
      };
    };

    systemd.services.nginx.after = [ config.shb.certs.certs.selfsigned.n.systemdService ];
    systemd.services.nginx.requires = [ config.shb.certs.certs.selfsigned.n.systemdService ];
  };

  ldap = { config, pkgs, ... }: {
    imports = [
      ../modules/blocks/lldap.nix
    ];

    networking.hosts = {
      "127.0.0.1" = [ "ldap.${config.test.domain}" ];
    };

    shb.hardcodedsecret.ldapUserPassword = {
      request = config.shb.lldap.ldapUserPassword.request;
      settings.content = "ldapUserPassword";
    };
    shb.hardcodedsecret.jwtSecret = {
      request = config.shb.lldap.jwtSecret.request;
      settings.content = "jwtSecrets";
    };

    shb.lldap = {
      enable = true;
      inherit (config.test) domain;
      subdomain = "ldap";
      ldapPort = 3890;
      webUIListenPort = 17170;
      dcdomain = "dc=example,dc=com";
      ldapUserPassword.result = config.shb.hardcodedsecret.ldapUserPassword.result;
      jwtSecret.result = config.shb.hardcodedsecret.jwtSecret.result;
      debug = false; # Enable this if needed, but beware it is _very_ verbose.

      ensureUsers = {
        alice = {
          email = "alice@example.com";
          groups = [ "user_group" ];
          password.result.path = pkgs.writeText "alicePassword" "AlicePassword";
        };
        bob = {
          email = "bob@example.com";
          groups = [ "user_group" "admin_group" ];
          password.result.path = pkgs.writeText "bobPassword" "BobPassword";
        };
        # charlie = {
        #   email = "charlie@example.com";
        #   groups = [ ];
        #   password.result.path = pkgs.writeText "charliePassword" "CharliePassword";
        # };
      };

      ensureGroups = {
        user_group = {};
        admin_group = {};
      };
    };
  };

  sso = ssl: { config, pkgs, ... }: {
    imports = [
      ../modules/blocks/authelia.nix
    ];

    networking.hosts = {
      "127.0.0.1" = [ "${config.shb.authelia.subdomain}.${config.shb.authelia.domain}" ];
    };

    shb.authelia = {
      enable = true;
      inherit (config.test) domain;
      subdomain = "auth";
      ssl = config.shb.certs.certs.selfsigned.n;
      debug = true;

      ldapHostname = "127.0.0.1";
      ldapPort = config.shb.lldap.ldapPort;
      dcdomain = config.shb.lldap.dcdomain;

      secrets = {
        jwtSecret.result = config.shb.hardcodedsecret.autheliaJwtSecret.result;
        ldapAdminPassword.result = config.shb.hardcodedsecret.ldapAdminPassword.result;
        sessionSecret.result = config.shb.hardcodedsecret.sessionSecret.result;
        storageEncryptionKey.result = config.shb.hardcodedsecret.storageEncryptionKey.result;
        identityProvidersOIDCHMACSecret.result = config.shb.hardcodedsecret.identityProvidersOIDCHMACSecret.result;
        identityProvidersOIDCIssuerPrivateKey.result = config.shb.hardcodedsecret.identityProvidersOIDCIssuerPrivateKey.result;
      };
    };

    shb.hardcodedsecret.autheliaJwtSecret = {
      request = config.shb.authelia.secrets.jwtSecret.request;
      settings.content = "jwtSecret";
    };
    shb.hardcodedsecret.ldapAdminPassword = {
      request = config.shb.authelia.secrets.ldapAdminPassword.request;
      settings.content = "ldapUserPassword";
    };
    shb.hardcodedsecret.sessionSecret = {
      request = config.shb.authelia.secrets.sessionSecret.request;
      settings.content = "sessionSecret";
    };
    shb.hardcodedsecret.storageEncryptionKey = {
      request = config.shb.authelia.secrets.storageEncryptionKey.request;
      settings.content = "storageEncryptionKey";
    };
    shb.hardcodedsecret.identityProvidersOIDCHMACSecret = {
      request = config.shb.authelia.secrets.identityProvidersOIDCHMACSecret.request;
      settings.content = "identityProvidersOIDCHMACSecret";
    };
    shb.hardcodedsecret.identityProvidersOIDCIssuerPrivateKey = {
      request = config.shb.authelia.secrets.identityProvidersOIDCIssuerPrivateKey.request;
      settings.source = (pkgs.runCommand "gen-private-key" {} ''
        mkdir $out
        ${pkgs.openssl}/bin/openssl genrsa -out $out/private.pem 4096
      '') + "/private.pem";
    };
  };

}
