{ config, pkgs, lib, ... }:

let
  inherit (lib) mkOption;
  inherit (lib.types) attrsOf str submodule;

  cfg = config.shb.ldap;

  contracts = pkgs.callPackage ../contracts {};

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  lldap-cli = pkgs.lldap-cli.overrideAttrs (f: p: {
    version = "0-unstable-2024-01-19";

    src = pkgs.fetchFromGitHub {
      owner = "ibizaman";
      repo = "lldap-cli";
      rev = "e07e2cafaa68e926f1256449e4553b01a15f0a0c";
      hash = "sha256-qbXSJmx5spW9iViycRmQdYtI6KfysOxeAv7qI+sz25A=";
    };
  });

  lldap-cli-auth = pkgs.callPackage ({ stdenvNoCC, makeWrapper }: stdenvNoCC.mkDerivation {
    name = "lldap-cli";

    src = lldap-cli;

    nativeBuildInputs = [
      makeWrapper
    ];

    # No quotes around the value for LLDAP_PASSWORD because we want the value to not be enclosed in quotes.
    installPhase = ''
      makeWrapper ${lldap-cli}/bin/lldap-cli $out/bin/lldap-cli \
        --set LLDAP_USERNAME "admin" \
        --run 'export LLDAP_PASSWORD="$(cat ${cfg.ldapUserPassword.result.path})"' \
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

    ldapUserPassword = lib.mkOption {
      description = "LDAP admin user secret.";
      type = lib.types.submodule {
        options = contracts.secret.mkRequester {
          mode = "0440";
          owner = "lldap";
          group = "lldap";
          restartUnits = [ "lldap.service" ];
        };
      };
    };

    jwtSecret = lib.mkOption {
      description = "JWT secret.";
      type = lib.types.submodule {
        options = contracts.secret.mkRequester {
          mode = "0440";
          owner = "lldap";
          group = "lldap";
          restartUnits = [ "lldap.service" ];
        };
      };
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

    mount = lib.mkOption {
      type = contracts.mount;
      description = ''
        Mount configuration. This is an output option.

        Use it to initialize a block implementing the "mount" contract.
        For example, with a zfs dataset:

        ```
        shb.zfs.datasets."ldap" = {
          poolName = "root";
        } // config.shb.ldap.mount;
        ```
      '';
      readOnly = true;
      default = { path = "/var/lib/lldap"; };
    };

    backup = lib.mkOption {
      description = ''
        Backup configuration.
      '';
      type = lib.types.submodule {
        options = contracts.backup.mkRequester {
          # TODO: is there a workaround that avoid needing to use root?
          # root because otherwise we cannot access the private StateDiretory
          user = "root";
          # /private because the systemd service uses DynamicUser=true
          sourceDirectories = [
            "/var/lib/private/lldap"
          ];
        };
      };
    };

    groups = lib.mkOption {
      description = "LDAP Groups to manage declaratively following the [ldap group contract](./contracts-ldap-group.html).";
      default = {};
      example = lib.literalExpression ''
      {
        family = {};
      }
      '';
      type = attrsOf (submodule ({ name, config, ... }: {
        options = contracts.ldapgroup.mkProvider {
          settings = mkOption {
            description = ''
              Settings specific to the LLDAP provider.

              By default it is the same as the field name.
            '';
            default = {
              inherit name;
            };

            type = submodule {
              options = {
                name = mkOption {
                  description = "Name of the LDAP group";
                  type = str;
                  default = name;
                };
              };
            };
          };

          resultCfg = {
            name = config.settings.name;
            nameText = name;
          };
        };
      }));
    };

    deleteUnmanagedUsers = lib.mkOption {
      description = "Do not delete users that are not defined here.";
      type = lib.types.bool;
      default = false;
    };

    users = lib.mkOption {
      description = ''
        LDAP Users to manage declaratively.

        Each field is provided in two versions.
        The first version, without prefix, sets the attribute
        every time the configuration is applied, overwriting any changes in the UI.

        The second version, with the "initial" prefix, sets
        the attribute only once, on user creation. Any changes
        in the UI will survive next time the configuration is applied.

        If both are set, the one without the "initial" prefix wins.
      '';
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          email = lib.mkOption {
            description = ''
              Email address.

              Must be set: set either "email" field or "initialEmail" field.
            '';
            type = lib.types.nullOr lib.types.str;
            default = null;
          };

          initialEmail = lib.mkOption {
            description = ''
              Email address.

              Must be set: set either "email" field or "initialEmail" field.
            '';
            type = lib.types.nullOr lib.types.str;
            default = null;
          };

          displayName = lib.mkOption {
            description = "Display name. Optional";
            type = lib.types.nullOr lib.types.str;
            default = null;
          };

          initialDisplayName = lib.mkOption {
            description = "Display name. Optional";
            type = lib.types.nullOr lib.types.str;
            default = null;
          };

          firstName = lib.mkOption {
            description = "First name. Optional";
            type = lib.types.nullOr lib.types.str;
            default = null;
          };

          initialFirstName = lib.mkOption {
            description = "First name. Optional";
            type = lib.types.nullOr lib.types.str;
            default = null;
          };

          lastName = lib.mkOption {
            description = "Last name. Optional.";
            type = lib.types.nullOr lib.types.str;
            default = null;
          };

          initialLastName = lib.mkOption {
            description = "Last name. Optional.";
            type = lib.types.nullOr lib.types.str;
            default = null;
          };

          groups = lib.mkOption {
            description = "Groups this user is member of. The group must exist.";
            type = lib.types.listOf lib.types.str;
            default = [];
          };

          password = lib.mkOption {
            description = "User password. Optional.";
            type = lib.types.nullOr (lib.types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0440";
                owner = "lldap";
                group = "lldap";
                restartUnits = [ "lldap.service" ];
              };
            });
            default = null;
          };

          initialPassword = lib.mkOption {
            description = "User password. Optional.";
            type = lib.types.nullOr (lib.types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0440";
                owner = "lldap";
                group = "lldap";
                restartUnits = [ "lldap.service" ];
              };
            });
            default = null;
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
    users.groups.lldap = {};

    services.lldap = {
      enable = true;

      environment = {
        LLDAP_JWT_SECRET_FILE = toString cfg.jwtSecret.result.path;
        LLDAP_LDAP_USER_PASS_FILE = toString cfg.ldapUserPassword.result.path;

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

    assertions = [
      (let
        uppercases = builtins.filter (n: lib.strings.toLower n != n) (lib.mapAttrsToList (uid: u: uid) cfg.users);
      in {
        assertion = uppercases == [];
        message = "Users ID for LLDAP can only be lowercase, found: ${lib.concatStringsSep "," uppercases}";
      })
      # (let
      #   unknownGroups = lib.flatten(lib.mapAttrsToList (uid: u: lib.subtractLists (map (gid: g: gid) cfg.groups) u.groups) cfg.users);
      # in {
      #   assertion = unknownGroups == [];
      #   message = "All groups defined in user field must exist, the following ones are not defined: ${lib.concatStringsSep "," unknownGroups}";
      # })
    ];

    systemd.services.lldap.postStart =
      let
        login = [''
          set -euo pipefail

          sleep 3

          export LLDAP_USERNAME=admin
          export LLDAP_PASSWORD=$(cat ${cfg.ldapUserPassword.result.path})
          export LLDAP_HTTPURL=http://${config.services.lldap.settings.http_host}:${toString config.services.lldap.settings.http_port}

          eval $(${lldap-cli}/bin/lldap-cli login)
        ''];

        deleteGroups = [''
          allUids=(${lib.concatStringsSep " " (
            (lib.mapAttrsToList (id: g: g.settings.name) cfg.groups)
              ++ [ "lldap_admin" "lldap_password_manager" "lldap_strict_readonly" ])
          })
          echo All managed groups are: ''${allUids[*]}
          echo Other groups will be deleted if any
          
          for uid in $(${lldap-cli}/bin/lldap-cli group list | ${pkgs.jq}/bin/jq -r 'map(.displayName)[]'); do
            if [[ ! " ''${allUids[*]} " =~ [[:space:]]''${uid}[[:space:]] ]]; then
              echo Deleting group $uid
              ${lldap-cli}/bin/lldap-cli group del $uid
            fi
          done
        ''];

        createGroups = [''
          existingUids=$(${lldap-cli}/bin/lldap-cli group list | ${pkgs.jq}/bin/jq -r 'map(.displayName)[]')
          managedUids=(${lib.concatStringsSep " " (
            (lib.mapAttrsToList (id: g: g.settings.name) cfg.groups)
              ++ [ "lldap_admin" "lldap_password_manager" "lldap_strict_readonly" ])
          })
          echo All managed groups are: ''${managedUids[*]}
          for uid in ''${managedUids[*]}; do
            if [[ ! " ''${existingUids[*]} " =~ [[:space:]]''${uid}[[:space:]] ]]; then
              echo "Creating group $uid"
              ${lldap-cli}/bin/lldap-cli group add $uid
            fi
          done
        ''];

        deleteUsers = [''
          allUids=(${lib.concatStringsSep " " (
            (lib.mapAttrsToList (uid: u: uid) cfg.users)
            ++ [ "admin" ])
          })
          echo All managed users are: ''${allUids[*]}
          echo Other users will be deleted if any
          for uid in $(${lldap-cli}/bin/lldap-cli user list all | ${pkgs.jq}/bin/jq -r 'map(.id)[]'); do
            if [[ ! " ''${allUids[*]} " =~ [[:space:]]''${uid}[[:space:]] ]]; then
              echo Deleting user $uid
              ${lldap-cli}/bin/lldap-cli user del $uid
            fi
          done
        ''];

        createUsers = lib.mapAttrsToList (uid: u: let
            email = if u.email != null then u.email else u.initialEmail;

            password = if u.password != null then u.password else u.initialPassword;
            displayName = if u.displayName != null then u.displayName else u.initialDisplayName;
            firstName = if u.firstName != null then u.firstName else u.initialFirstName;
            lastName = if u.lastName != null then u.lastName else u.initialLastName;

            allCreateAttributes =
              lib.optionals    (password != null)    [''-p "$(cat ${password.result.path})"'']
              ++ lib.optionals (displayName != null) [''-d "${displayName}"'']
              ++ lib.optionals (firstName != null)   [''-f "${firstName}"'']
              ++ lib.optionals (lastName != null)    [''-l "${lastName}"''];

            allUpdateAttributes =
              lib.optionals    (u.email != null)       [''mail "${u.email}"'']
              ++ lib.optionals (u.password != null)    [''password "$(cat ${u.password.result.path})"'']
              ++ lib.optionals (u.displayName != null) [''display_name "${u.displayName}"'']
              ++ lib.optionals (u.firstName != null)   [''first_name "${u.firstName}"'']
              ++ lib.optionals (u.lastName != null)    [''last_name "${u.lastName}"''];
          in ''
          existingUids=($(${lldap-cli}/bin/lldap-cli user list all | ${pkgs.jq}/bin/jq -r 'map(.id)[]'))
          managedUids=(${lib.concatStringsSep " " (
            (lib.mapAttrsToList (id: u: id) cfg.users)
              ++ [ "admin" ])
          })
          echo All managed users are: ''${managedUids[*]}
          echo Existing managed users are: ''${existingUids[*]}
          set -x
          for uid in ''${managedUids[*]}; do
            echo "Checking user $uid"
            if [[ ! " ''${existingUids[*]} " =~ [[:space:]]''${uid}[[:space:]] ]]; then
              echo "Creating user $uid"
              ${lldap-cli}/bin/lldap-cli user add ${uid} "${email}" ${lib.concatStringsSep " " allCreateAttributes}
            else
              echo "Updating user $uid"
              ${lib.concatMapStringsSep "\n    " (x: "${lldap-cli}/bin/lldap-cli user update set ${uid} ${x}") allUpdateAttributes}
            fi
          done
          set +x
        '') cfg.users;

        addToGroups = lib.mapAttrsToList (uid: u: ''
          existingUids=$(${lldap-cli}/bin/lldap-cli user group list ${uid})
          managedUids=(${lib.concatStringsSep " " u.groups})
          echo All managed groups for user ${uid} are: ''${managedUids[*]}
          for gid in ''${managedUids[*]}; do
            if [[ ! " ''${existingUids[*]} " =~ [[:space:]]''${gid}[[:space:]] ]]; then
              echo "Adding group $gid to user ${uid}"
              ${lldap-cli}/bin/lldap-cli user group add \
                ${uid} \
                $gid
            fi
          done
        '') cfg.users;

        deleteFromGroups = lib.mapAttrsToList (uid: u: ''
          managedUids=(${lib.concatStringsSep " " u.groups})
          echo All managed groups for user ${uid} are: ''${managedUids[*]}
          for gid in $(${lldap-cli}/bin/lldap-cli user group list ${uid}); do
            if [[ ! " ''${managedUids[*]} " =~ [[:space:]]''${gid}[[:space:]] ]]; then
              echo "Removing group $gid from user $uid"
              ${lldap-cli}/bin/lldap-cli user group del \
                ${uid} \
                $gid
            fi
          done
        '') cfg.users;
      in
        lib.concatStringsSep "\n\n" (
          login
          ++ deleteGroups
          ++ createGroups
          ++ lib.optionals cfg.deleteUnmanagedUsers deleteUsers
          ++ createUsers
          ++ addToGroups
          ++ deleteFromGroups
        );
  };
}
