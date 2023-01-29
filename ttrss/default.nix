{ customPkgs
, pkgs
, utils
}:
{ serviceName ? "Ttrss"
, siteName ? "ttrss"
, subdomain ? "ttrss"
, domain ? ""
, ingress ? 18010

, user ? "ttrss"
, group ? "ttrss"
, documentRoot ? "/usr/share/webapps/ttrss"
, postgresDatabase ? "ttrss"
, postgresUser ? "ttrss"
, postgresPasswordLocation ? "ttrss"

, smtp ? {}
, sso ? {}

, distribution ? {}

, configPkg ? pkgs.callPackage (import ./config.nix) {}
, normalizeHeaderPkg ? pkgs.callPackate (import ./normalize-headers.nix) {}
, updateServicePkg ? pkgs.callPackage (import ./update.nix) {inherit utils;}
, dbupgradePkg ? pkgs.callPackage (import ./dbupgrade.nix) {}
}:

with pkgs.lib.attrsets;
let
  rtdir = "/run/ttrss";
  lock_directory = "${rtdir}/lock";
  cache_directory = "${rtdir}/cache";
  persistent_dir = "/var/lib/${siteName}";
  feed_icons_directory = "${persistent_dir}/feed-icons";
in
rec {
  dnsmasqSubdomains = [subdomain];

  db = customPkgs.mkPostgresDB {
    name = "${serviceName}PostgresDB";

    database = postgresDatabase;
    username = postgresUser;
    # TODO: use passwordFile
    password = postgresPasswordLocation;
  };

  config =
    let
      domain = utils.getDomain distribution "${serviceName}Config";
    in
      configPkg {
        name = "ttrss";
        serviceName = "${serviceName}Config";

        inherit subdomain;
        inherit documentRoot;
        inherit lock_directory cache_directory feed_icons_directory;
        inherit (phpfpmService) user group;
        inherit domain;

        db_host = db: db.target.properties.hostname;
        db_port = (utils.getTarget distribution "TtrssPostgresDB").containers.postgresql-database.port;
        db_database = postgresDatabase;
        db_username = postgresUser;
        # TODO: use passwordFile
        db_password = postgresPasswordLocation;
        enabled_plugins = [ "auth_remote" "note" ];
        auth_remote_post_logout_url = "https://keycloak.${domain}/realms/${sso.realm}/account";

        dependsOn = {
          inherit db;
        };
      };

  dbupgrade = dbupgradePkg {
    name = "${serviceName}DBUpgrade";

    inherit user;
    binDir = documentRoot;

    dependsOn = {
      inherit config db;
    };
  };

  service = customPkgs.mkNginxService {
    name = "${serviceName}Service";

    inherit siteName;
    inherit user group;
    runtimeDirectory = "/run/nginx";

    config = {
      port = ingress;
      inherit siteName;
      siteRoot = documentRoot;
      phpFpmSiteSocket = phpfpmService.siteSocket;
    };

    dependsOn = {
    };
  };

  phpfpmService = customPkgs.mkPHPFPMService {
    name = "${serviceName}PHPFPMService";

    inherit siteName;
    runtimeDirectory = rtdir;

    # Must match haproxy for socket
    inherit user group;
    socketUser = service.user;
    socketGroup = service.group;

    phpIniConfig = {
      prependFile = normalizeHeaderPkg {
        debug = true;
      };
    };

    siteConfig = {
      siteRoot = documentRoot;
    };
  };

  updateService = updateServicePkg {
    name = "${serviceName}UpdateService";

    inherit documentRoot;
    inherit (phpfpmService) user group;
    readOnlyPaths = [];
    readWritePaths = [
      lock_directory
      cache_directory
      feed_icons_directory
    ];
    postgresServiceName = (utils.getTarget distribution "TtrssPostgresDB").containers.postgresql-database.service_name;

    dependsOn = {
      inherit config db dbupgrade;
    };
  };

  haproxy = {
    frontend = {
      acl = {
        acl_ttrss = "hdr_beg(host) ttrss.";
      };
      use_backend = "if acl_ttrss";
    };
    backend = {
      servers = [
        {
          name = "ttrss1";
          address = service.nginxSocket;
          balance = "roundrobin";
          check = {
            inter = "5s";
            downinter = "15s";
            fall = "3";
            rise = "3";
          };
          httpcheck = "GET /";
          # captureoutput = {
          #   firstport = "3000";
          #   secondport = "3001";
          #   issocket = true;
          #   outputfile = "/tmp/haproxy/ttrss.stream";
          # };
        }
      ];
    };
    debugHeaders = "acl_ttrss";
  };

  keycloakCliConfig = {
    clients = {
      ttrss = {
        roles = ["uma_protection"];
      };
    };
  };

  services = {
    ${db.name} = db;
    ${config.name} = config;
    ${dbupgrade.name} = dbupgrade;
    ${service.name} = service;
    ${phpfpmService.name} = phpfpmService;
    ${updateService.name} = updateService;
  };

  distribute = on: {
    ${db.name} = on;
    ${config.name} = on;
    ${dbupgrade.name} = on;
    ${service.name} = on;
    ${phpfpmService.name} = on;
    ${updateService.name} = on;
  };

  directories_modes = {
    "${rtdir}" = "0550";
    "${lock_directory}" = "0770";
    "${cache_directory}" = "0770";
    "${cache_directory}/upload" = "0770";
    "${cache_directory}/images" = "0770";
    "${cache_directory}/export" = "0770";
    "${feed_icons_directory}" = "0770";
  };
}
