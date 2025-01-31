{ pkgs, lib }:
let
  inherit (lib) hasAttr mkOption optionalString;
  inherit (lib.types) listOf nullOr submodule str;

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
        # print(r)
        return json.loads(r)

    def unline_with(j, s):
        return j.join((x.strip() for x in s.split("\n")))

    ''
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
    + (optionalString (hasAttr "test" nodes.client && hasAttr "login" nodes.client.test) ''
    with subtest("Login"):
        code, logs = client.execute("login_playwright firefox")
        client.copy_from_vm("trace")
        print(logs)
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
    };
    imports = [
      baseImports
      ../modules/blocks/postgresql.nix
      ../modules/blocks/authelia.nix
      ../modules/blocks/nginx.nix
      ../modules/blocks/hardcodedsecret.nix
    ];
    config = {
      # HTTP(s) server port.
      networking.firewall.allowedTCPPorts = [ 80 443 ];
    };
  };

  clientLoginModule = { config, pkgs, ... }: let
    cfg = config.test.login;
  in {
    options.test.login = {
      usernameFieldLabelRegex = mkOption {
        type = str;
        default = "[Uu]sername";
      };
      passwordFieldLabelRegex = mkOption {
        type = str;
        default = "[Pp]assword";
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
                "chromium": ["--headless", "--disable-gpu"],
                "firefox": [],
                "webkit": []
            }
            if len(sys.argv) != 2 or sys.argv[1] not in browsers.keys():
                print(f"usage: {sys.argv[0]} [{'|'.join(browsers.keys())}]")
                sys.exit(1)
            browser_name = sys.argv[1]
            browser_args = browsers.get(browser_name)
            print(f"Running test on {browser_name} {' '.join(browser_args)}")

            with open("${testCfg}") as f:
                testCfg = json.load(f)

            with sync_playwright() as p:
                browser = getattr(p, browser_name).launch(args=browser_args)

                for i, u in enumerate(testCfg["testLoginWith"]):
                    print(f"Testing for user {u['username']} and password {u['password']}")

                    context = browser.new_context(ignore_https_errors=True)
                    context.set_default_navigation_timeout(2 * 60 * 1000)
                    context.tracing.start(screenshots=True, snapshots=True, sources=True)
                    try:
                        page = context.new_page()
                        print(f"Going to {testCfg['startUrl']}")
                        page.goto(testCfg['startUrl'])
      
                        if u['username'] is not None:
                            print(f"Filling field {testCfg['usernameFieldLabelRegex']} with {u['username']}")
                            page.get_by_label(re.compile(testCfg['usernameFieldLabelRegex'])).fill(u['username'])
                        if u['password'] is not None:
                            print(f"Filling field {testCfg['passwordFieldLabelRegex']} with {u['password']}")
                            page.get_by_label(re.compile(testCfg['passwordFieldLabelRegex'])).fill(u['password'])

                        # Assumes we don't need to login, so skip this.
                        if u['username'] is not None or u['password'] is not None:
                            print(f"Clicking button {testCfg['loginButtonNameRegex']}")
                            page.get_by_role("button", name=re.compile(testCfg['loginButtonNameRegex'])).click()

                        for line in u['nextPageExpect']:
                            print(f"Running: {line}")
                            print(f"Page has title: {page.title()}")
                            eval(line)
                    finally:
                        page.screenshot(path=f"trace/{i}/final.png")
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
      ../modules/blocks/ldap.nix
    ];

    networking.hosts = {
      "127.0.0.1" = [ "ldap.${config.test.domain}" ];
    };

    shb.hardcodedsecret.ldapUserPassword = {
      request = config.shb.ldap.ldapUserPassword.request;
      settings.content = "ldapUserPassword";
    };
    shb.hardcodedsecret.jwtSecret = {
      request = config.shb.ldap.jwtSecret.request;
      settings.content = "jwtSecrets";
    };

    shb.ldap = {
      enable = true;
      inherit (config.test) domain;
      subdomain = "ldap";
      ldapPort = 3890;
      webUIListenPort = 17170;
      dcdomain = "dc=example,dc=com";
      ldapUserPassword.result = config.shb.hardcodedsecret.ldapUserPassword.result;
      jwtSecret.result = config.shb.hardcodedsecret.jwtSecret.result;
    };
  };

  sso = ssl: { config, pkgs, ... }: {
    imports = [
      ../modules/blocks/authelia.nix
    ];

    networking.hosts = {
      "127.0.0.1" = [ "auth.${config.test.domain}" ];
    };

    shb.authelia = {
      enable = true;
      inherit (config.test) domain;
      subdomain = "auth";
      ssl = config.shb.certs.certs.selfsigned.n;

      ldapHostname = "127.0.0.1";
      ldapPort = config.shb.ldap.ldapPort;
      dcdomain = config.shb.ldap.dcdomain;

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
