{ system, pkgs, distribution, invDistribution }:

let
  utils = pkgs.lib.callPackageWith pkgs ./utils.nix { };

  customPkgs = (pkgs.callPackage (./../../..) {}).customPkgs {
    inherit system pkgs utils;
  };

  getTarget = name: builtins.elemAt (builtins.getAttr name distribution) 0;

  getDomain = name: (getTarget name).containers.system.domain;

  realm = "myrealm";

  smtp = utils.recursiveMerge [
    {
      from = "vaultwarden@${realm}.com";
      fromName = "vaultwarden";
      port = 587;
      authMechanism = "Login";
    }
    vaultwarden.smtp
  ];

  keycloak = customPkgs.keycloak {};

  KeycloakService = customPkgs.mkKeycloakService {
    name = "KeycloakService";
    subdomain = keycloak.subdomain;

    # TODO: Get these from infrastructure.nix
    user = "keycloak";
    group = "keycloak";

    postgresServiceName = (getTarget "KeycloakPostgresDB").containers.postgresql-database.service_name;
    initialAdminUsername = "admin";

    keys = {
      dbPassword = "keycloakdbpassword";
      initialAdminPassword = "keycloakinitialadmin";
    };

    # logLevel = "DEBUG,org.hibernate:info,org.keycloak.authentication:debug,org.keycloak:info,org.postgresql:info,freemarker:info";
    logLevel = "INFO";
    hostname = "${keycloak.subdomain}.${getDomain "KeycloakService"}";
    listenPort = 8080;

    dbType = "postgres";
    dbDatabase = keycloak.database.name;
    dbUsername = keycloak.database.username;
    dbHost = {KeycloakPostgresDB}: KeycloakPostgresDB.target.properties.hostname;
    dbPort = (getTarget "KeycloakPostgresDB").containers.postgresql-database.port;

    KeycloakPostgresDB = keycloak.db;
  };

  KeycloakCliService = customPkgs.mkKeycloakCliService rec {
    name = "KeycloakCliService";

    keycloakServiceName = "keycloak.service";
    keycloakSecretsDir = (getTarget name).containers.keycloaksecrets.rootdir;
    keycloakUrl = "https://${keycloak.subdomain}.${(getDomain "KeycloakService")}";
    keycloakUser = KeycloakService.initialAdminUsername;
    keys = {
      userpasswords = "keycloakusers";
    };

    dependsOn = {
      inherit KeycloakService HaproxyService;
    };

    config = (utils.recursiveMerge [
      rec {
        inherit realm;
        domain = getDomain name;
        roles = {
          user = [];
          admin = ["user"];
        };
        users = {
          me = {
            email = "me@${domain}";
            firstName = "Me";
            lastName = "Me";
            roles = ["admin"];
            initialPassword = true;
          };
          friend = {
            email = "friend@${domain}";
            firstName = "Friend";
            lastName = "Friend";
            roles = ["user"];
            initialPassword = true;
          };
        };
      }
      vaultwarden.keycloakCliConfig
    ]);
  };

  KeycloakHaproxyService = customPkgs.mkKeycloakHaproxyService {
    name = "KeycloakHaproxyService";

    domain = "https://${keycloak.subdomain}.${getDomain "KeycloakService"}";
    realms = [realm];

    inherit KeycloakService;
  };

  vaultwarden = customPkgs.vaultwarden {
    subdomain = "vaultwarden";
    ingress = 18005;
    sso.realm = realm;
    sso.userRole = "user";
    sso.adminRole = "admin";

    inherit smtp;

    inherit distribution HaproxyService KeycloakService KeycloakCliService;
  };

  HaproxyService = customPkgs.mkHaproxyService {
    name = "HaproxyService";

    user = "http";
    group = "http";

    dependsOn = {
      inherit KeycloakHaproxyService;
    };

    config = {...}:
      let
        domain = getDomain "HaproxyService";
      in {
        certPath = "/var/lib/acme/${domain}/full.pem";
        stats = {
          port = 8404;
          uri = "/stats";
          refresh = "10s";
          prometheusUri = "/metrics";
        };
        defaults = {
          default-server = "init-addr last,none";
        };
        resolvers = {
          default = {
            nameservers = {
              ns1 = "127.0.0.1:53";
            };
          };
        };
        sites = {
          vaultwarden = vaultwarden.haproxy distribution.VaultwardenService;
          keycloak = {
            frontend = {
              capture = [
                "request header origin len 128"
              ];
              acl = {
                acl_keycloak = "hdr_beg(host) ${keycloak.subdomain}.";
                acl_keycloak_authorized_origin = "capture.req.hdr(0) -m end .${domain}";
              };
              use_backend = "if acl_keycloak";
              http-response = {
                add-header = map (x: x + " if acl_keycloak_authorized_origin") [
                  "Access-Control-Allow-Origin %[capture.req.hdr(0)]"
                  "Access-Control-Allow-Methods GET,\\ HEAD,\\ OPTIONS,\\ POST,\\ PUT"
                  "Access-Control-Allow-Credentials true"
                  "Access-Control-Allow-Headers Origin,\\ Accept,\\ X-Requested-With,\\ Content-Type,\\ Access-Control-Request-Method,\\ Access-Control-Request-Headers,\\ Authorization"
                ];
              };
            };
            backend = {
              servers = [
                {
                  name = "keycloak1";
                  address = "127.0.0.1:8080"; # TODO: should use the hostname
                  resolvers = "default";
                }
              ];
              cookie = "JSESSIONID prefix";
            };
          };
        };
      };
  };
in

with pkgs.lib.attrsets;
rec {
  inherit KeycloakPostgresDB KeycloakService KeycloakCliService KeycloakHaproxyService;

  inherit HaproxyService;
}
// keycloak.services
// vaultwarden.services
