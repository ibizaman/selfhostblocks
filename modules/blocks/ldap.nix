{ config, pkgs, lib, ... }:

let
  cfg = config.shb.ldap;

  contracts = pkgs.callPackage ../contracts {};

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  lldap-cli-auth = pkgs.callPackage ({ stdenvNoCC, makeWrapper, lldap-cli }: stdenvNoCC.mkDerivation {
    name = "lldap-cli";

    src = lldap-cli;

    nativeBuildInputs = [
      makeWrapper
    ];

    # No quotes around the value for LLDAP_PASSWORD because we want the value to not be enclosed in quotes.
    installPhase = ''
      makeWrapper ${pkgs.lldap-cli}/bin/lldap-cli $out/bin/lldap-cli \
        --set LLDAP_USERNAME "admin" \
        --set LLDAP_PASSWORD $(cat ${cfg.ldapUserPasswordFile}) \
        --set LLDAP_HTTPURL "http://${config.services.lldap.settings.http_host}:${toString config.services.lldap.settings.http_port}"
    '';
  }) {};
in
{
  options.shb.ldap = {
    enable = lib.mkEnableOption "the LDAP service";

    dcdomain = lib.mkOption {
      type = lib.types.str;
      description = "dc domain to serve.";
      example = "dc=mydomain,dc=com";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which the LDAP service will be served.";
      example = "grafana";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain under which the LDAP service will be served.";
      example = "mydomain.com";
    };

    ldapPort = lib.mkOption {
      type = lib.types.port;
      description = "Port on which the server listens for the LDAP protocol.";
      default = 3890;
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    webUIListenPort = lib.mkOption {
      type = lib.types.port;
      description = "Port on which the web UI is exposed.";
      default = 17170;
    };

    ldapUserPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the LDAP admin user password.";
    };

    jwtSecretFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the JWT secret.";
    };

    restrictAccessIPRange = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Set a local network range to restrict access to the UI to only those IPs.";
      example = "192.168.1.1/24";
      default = null;
    };

    debug = lib.mkOption {
      description = "Enable debug logging.";
      type = lib.types.bool;
      default = false;
    };

    groups = lib.mkOption {
      description = "LDAP Groups to manage declaratively.";
      default = {};
      example = lib.literalExpression ''
      {
        family = {};
      }
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {};
      });
    };

    users = lib.mkOption {
      description = "LDAP Users to manage declaratively.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          email = lib.mkOption {
            description = "Email address.";
            type = lib.types.str;
          };

          displayName = lib.mkOption {
            description = "Display name.";
            type = lib.types.str;
          };

          firstName = lib.mkOption {
            description = "First name.";
            type = lib.types.str;
          };

          lastName = lib.mkOption {
            description = "Last name.";
            type = lib.types.str;
          };

          groups = lib.mkOption {
            description = "Groups this user is member of. The group must exist.";
            type = lib.types.listOf lib.types.str;
            default = [];
          };

          passwordFile = lib.mkOption {
            type = lib.types.path;
            description = "File containing the user's password.";
          };
        };
      });
    };
  };
  
  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;

      virtualHosts.${fqdn} = {
        forceSSL = !(isNull cfg.ssl);
        sslCertificate = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.cert;
        sslCertificateKey = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.key;
        locations."/" = {
          extraConfig = ''
            proxy_set_header Host $host;
          '' + (if isNull cfg.restrictAccessIPRange then "" else ''
            allow ${cfg.restrictAccessIPRange};
            deny all;
          '');
          proxyPass = "http://${toString config.services.lldap.settings.http_host}:${toString config.services.lldap.settings.http_port}/";
        };
      };
    };

    users.users.lldap = {
      name = "lldap";
      group = "lldap";
      isSystemUser = true;
    };

    users.groups.lldap = {
      members = [ "backup" ];
    };

    services.lldap = {
      enable = true;

      environment = {
        LLDAP_JWT_SECRET_FILE = toString cfg.jwtSecretFile;
        LLDAP_LDAP_USER_PASS_FILE = toString cfg.ldapUserPasswordFile;

        RUST_LOG = lib.mkIf cfg.debug "debug";
      };

      settings = {
        http_url = "https://${fqdn}";
        http_host = "127.0.0.1";
        http_port = cfg.webUIListenPort;

        ldap_host = "127.0.0.1";
        ldap_port = cfg.ldapPort;

        ldap_base_dn = cfg.dcdomain;

        verbose = cfg.debug;
      };
    };

    environment.systemPackages = [
      lldap-cli-auth
    ];

    # $ lldap-cli schema attribute user list
    #
    # Name           Type       Is list  Is visible  Is editable
    # ----           ----       -------  ----------  -----------
    # avatar         JpegPhoto  false    true        true
    # creation_date  DateTime   false    true        false
    # display_name   String     false    true        true
    # first_name     String     false    true        true
    # last_name      String     false    true        true
    # mail           String     false    true        true
    # user_id        String     false    true        false
    # uuid           String     false    true        false


    # $ lldap-cli schema attribute group list
    #
    # Name           Type      Is list  Is visible  Is editable
    # ----           ----      -------  ----------  -----------
    # creation_date  DateTime  false    true        false
    # display_name   String    false    true        true
    # group_id       Integer   false    true        false
    # uuid           String    false    true        false

    systemd.services.lldap.postStart =
      let
        configFile = (pkgs.formats.toml {}).generate "lldap_config.toml" config.services.lldap.settings;

        login = [''
          set -euo pipefail

          sleep 3

          export LLDAP_USERNAME=admin
          export LLDAP_PASSWORD=$(cat ${cfg.ldapUserPasswordFile})
          export LLDAP_HTTPURL=http://${config.services.lldap.settings.http_host}:${toString config.services.lldap.settings.http_port}

          eval $(${pkgs.lldap-cli}/bin/lldap-cli login)

          set -x
        ''];

        deleteGroups = [''
          allUids=(${lib.concatStringsSep " " (
            (lib.mapAttrsToList (uid: g: uid) cfg.groups)
              ++ [ "lldap_admin" "lldap_password_manager" "lldap_strict_readonly" ])
          })
          echo All managed groups are: $allUids
          echo Other groups will be deleted
          for uid in $(${pkgs.lldap-cli}/bin/lldap-cli group list); do
            if [[ ! " ''${allUids[*]} " =~ [[:space:]]''${uid}[[:space:]] ]]; then
              ${pkgs.lldap-cli}/bin/lldap-cli group del $uid
            fi
          done
        ''];

        createGroups = lib.mapAttrsToList (uid: g: ''
          ${pkgs.lldap-cli}/bin/lldap-cli group add ${uid}
        '') cfg.groups;

        deleteUsers = [''
          allUids=(${lib.concatStringsSep " " (
            (lib.mapAttrsToList (uid: u: uid) cfg.users)
            ++ [ "admin" ])
          })
          for uid in $(${pkgs.lldap-cli}/bin/lldap-cli user list uid); do
            if [[ ! " ''${allUids[*]} " =~ [[:space:]]''${uid}[[:space:]] ]]; then
              ${pkgs.lldap-cli}/bin/lldap-cli user del $uid
            fi
          done
        ''];

        createUsers = lib.mapAttrsToList (uid: u: ''
          ${pkgs.lldap-cli}/bin/lldap-cli user add ${uid} "${u.email}"
          ${pkgs.lldap-cli}/bin/lldap-cli user update set ${uid} password "$(cat ${u.passwordFile})"
          ${pkgs.lldap-cli}/bin/lldap-cli user update set ${uid} mail "${u.email}"
          ${pkgs.lldap-cli}/bin/lldap-cli user update set ${uid} display_name "${u.displayName}"
          # ${pkgs.lldap-cli}/bin/lldap-cli user update set ${uid} first_name "${u.firstName}"
          # ${pkgs.lldap-cli}/bin/lldap-cli user update set ${uid} last_name "${u.lastName}"
        '') cfg.users;

        addToGroups = lib.mapAttrsToList (uid: u: lib.concatMapStringsSep "\n" (g: ''
          ${pkgs.lldap-cli}/bin/lldap-cli user group add \
            ${uid} \
            ${g}
        '') u.groups) cfg.users;
      in
        lib.concatStringsSep "\n\n" (
          login
          ++ deleteGroups
          ++ createGroups
          ++ deleteUsers
          ++ createUsers
          ++ addToGroups
        );

    shb.backup.instances.lldap = {
      sourceDirectories = [
        "/var/lib/lldap"
      ];
    };
  };
}
