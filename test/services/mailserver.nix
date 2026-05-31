{
  lib,
  pkgs,
  shb,
  ...
}:
let
  domain = "example.com";
  subdomain = "imap";
  fqdn = "${subdomain}.${domain}";

  trySendMail = pkgs.writeShellApplication {
    name = "trySendMail";
    runtimeInputs = [
      pkgs.swaks
    ];
    text = ''
      USER="''${1:-}"
      PASSWORD="''${2:-}"

      if [ -z "$USER" ]; then
        echo "No user given"
        exit 1
      fi

      if [ -z "$PASSWORD" ]; then
        swaks \
          --server ${fqdn} \
          --port 465 \
          --tls-on-connect \
          --from "$USER" \
          --to "$USER"
      else
        swaks \
          --server ${fqdn} \
          --port 465 \
          --tls-on-connect \
          --auth LOGIN \
          --auth-user "$USER" \
          --auth-password "$PASSWORD" \
          --from "$USER" \
          --to "$USER"
      fi
    '';
  };

  tryRcvMail = pkgs.writeShellApplication {
    name = "tryRcvMail";
    runtimeInputs = [
      pkgs.curl
    ];
    text = ''
      USER="''${1:-}"
      PASSWORD="''${2:-}"

      if [ -z "$USER" ]; then
        echo "No user given"
        exit 1
      fi
      if [ -z "$PASSWORD" ]; then
        echo "No password given"
        exit 1
      fi

      curl -s --url "imaps://imap.example.com/INBOX;UID=1" \
        --user "$USER:$PASSWORD"
    '';
  };
in
{
  basic = shb.test.runNixOSTest {
    name = "mailserver_basic";

    # Connect to the running VM started with driverInteractive:
    #   ssh-keygen -R 'vsock-mux//run/user/1000/tmpcf3hs4yp/server_host.socket'; ssh -o User=root vsock-mux//run/user/1000/tmpcf3hs4yp/server_host.socket
    interactive.sshBackdoor.enable = true;

    nodes.server =
      { config, ... }:
      {
        imports = [
          ../../modules/blocks/ssl.nix
          ../../modules/services/mailserver.nix
        ];

        networking.hosts = {
          "127.0.0.1" = [ fqdn ];
        };

        shb.certs.cas.selfsigned.myca = {
          name = "My CA";
        };
        shb.certs.certs.selfsigned = {
          ${domain} = {
            ca = config.shb.certs.cas.selfsigned.myca;

            domain = "*.${domain}";
            group = "nginx";
          };
        };

        shb.mailserver = {
          enable = true;
          inherit subdomain domain;
          stateVersion = 4;
          ssl = config.shb.certs.certs.selfsigned.${domain};

          # imapSync = {
          #   # syncTimer = "10s";
          #   # debug = false;
          #   # accounts.fastmail = {
          #   #   host = "imap.fastmail.com";
          #   #   port = 993;
          #   #   username = email;
          #   #   password.result = config.shb.sops.secret."mailserver/imap/fastmail/password".result;
          #   #   mapSpecialJunk = "Spam";
          #   # };
          # };

          # smtpRelay = {
          #   host = "smtp.fastmail.com";
          #   port = 587;
          #   username = email;
          #   password.result = config.shb.sops.secret."mailserver/smtp/fastmail/password".result;
          # };

        };

        mailserver.mailboxes = {
          Junk = {
            auto = "subscribe";
            special_use = "\\Junk";
          };
        };

        environment.systemPackages = [
          pkgs.openssl
          pkgs.swaks
          trySendMail
          tryRcvMail
        ];

        specialisation = {
          ldap.configuration =
            { config, ... }:
            {
              imports = [
                ../../modules/blocks/hardcodedsecret.nix
                ../../modules/blocks/lldap.nix
              ];

              networking.hosts = {
                "127.0.0.1" = [ "ldap.${domain}" ];
              };

              environment.systemPackages = [
                pkgs.openldap
              ];

              shb.hardcodedsecret.ldapUserPassword = {
                request = config.shb.lldap.ldapUserPassword.request;
                settings.content = "ldapUserPassword";
              };
              shb.hardcodedsecret.jwtSecret = {
                request = config.shb.lldap.jwtSecret.request;
                settings.content = "jwtSecrets";
              };
              shb.hardcodedsecret.alice = {
                request = config.shb.lldap.ensureUsers.alice.password.request;
                settings.content = "AlicePassword";
              };
              shb.hardcodedsecret.charlie = {
                request = config.shb.lldap.ensureUsers.charlie.password.request;
                settings.content = "CharliePassword";
              };

              shb.lldap = {
                enable = true;
                inherit domain;
                subdomain = "ldap";
                ldapPort = 3890;
                webUIListenPort = 17170;
                dcdomain = "dc=example,dc=com";
                ldapUserPassword.result = config.shb.hardcodedsecret.ldapUserPassword.result;
                jwtSecret.result = config.shb.hardcodedsecret.jwtSecret.result;
                debug = true;

                ensureUsers = {
                  alice = {
                    email = "alice@example.com";
                    groups = [ "user_group" ];
                    password.result = config.shb.hardcodedsecret.alice.result;
                  };
                  charlie = {
                    email = "charlie@example.com";
                    groups = [ "other_group" ];
                    password.result = config.shb.hardcodedsecret.charlie.result;
                  };
                };

                ensureGroups = {
                  user_group = { };
                  admin_group = { };
                  other_group = { };
                };
              };

              shb.mailserver = {
                ldap = {
                  enable = true;
                  host = "127.0.0.1";
                  port = config.shb.lldap.ldapPort;
                  dcdomain = config.shb.lldap.dcdomain;
                  adminName = "admin";
                  adminPassword.result = config.shb.hardcodedsecret.ldapUserPassword.result;
                  account = "fastmail";
                  userGroup = "user_group";
                };
              };
            };
        };
      };

    testScript =
      { nodes, ... }:
      let
        specialisations = "${nodes.server.system.build.toplevel}/specialisation";
        switch = name: "${specialisations}/${name}/bin/switch-to-configuration test";

        ldapSearch =
          let
            config = nodes.server.specialisation.ldap.configuration;
          in
          lib.concatStringsSep " " [
            "ldapsearch"
            "-H ldap://ldap.example.com:${toString config.shb.lldap.ldapPort}"
          ];
        ldapSearchAdmin =
          let
            config = nodes.server.specialisation.ldap.configuration;
          in
          lib.concatStringsSep " " [
            "ldapsearch"
            "-H ldap://ldap.example.com:${toString config.shb.lldap.ldapPort}"
            "-D uid=admin,ou=people,${config.shb.lldap.dcdomain}"
            "-w ${config.shb.hardcodedsecret.ldapUserPassword.settings.content}"
          ];
      in
      ''
        server.wait_for_unit("multi-user.target")
        server.wait_for_unit("dovecot")

        with subtest("ldap"):
            server.succeed("${switch "ldap"}")

            server.wait_for_unit("lldap")
            print(server.succeed("${ldapSearch} -LLL -D uid=alice,ou=people,dc=example,dc=com -w AlicePassword -b cn=user_group,ou=groups,dc=example,dc=com | grep uniquemember | grep alice"))
            print(server.succeed("${ldapSearchAdmin} -LLL -b cn=user_group,ou=groups,dc=example,dc=com | grep uniquemember | grep alice"))

            server.wait_for_unit("dovecot")
            print(server.fail("doveadm auth test auser@example.com apassword"))
            print(server.fail("doveadm auth test charlie@example.com CharliePassword"))
            print(server.succeed("doveadm auth test alice@example.com AlicePassword"))

            server.wait_for_unit("postfix")
            print(server.fail("trySendMail alice@example.com"))
            print(server.fail("trySendMail auser@example.com apassword"))
            print(server.fail("trySendMail charlie@example.com CharliePassword"))
            print(server.succeed("trySendMail alice@example.com AlicePassword"))

            print(server.fail("tryRcvMail charlie@example.com CharliePassword"))
            print(server.succeed("tryRcvMail alice@example.com AlicePassword"))

            print(server.succeed("find /var/vmail"))
            print(server.succeed("find /var/vmail/fastmail/alice@example.com"))
      '';
  };
}
