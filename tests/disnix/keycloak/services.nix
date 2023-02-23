{ system, pkgs, distribution, invDistribution }:

let
  utils = pkgs.lib.callPackageWith pkgs ../../../utils.nix { };

  customPkgs = import ../../../pkgs/all-packages.nix {
    inherit system pkgs utils;
  };
in
{
  KeycloakPostgresDB = customPkgs.mkPostgresDB {
    name = "KeycloakPostgresDB";
    database = "keycloak";
    username = "keycloak";
    # TODO: use passwordFile
    password = "keycloak";
  };

  KeycloakService = customPkgs.mkKeycloakService {
    name = "KeycloakService";

    # Get these from infrastructure.nix
    user = "keycloak";
    group = "keycloak";

    postgresServiceName = (utils.getTarget "KeycloakPostgresDB").containers.postgresql-database.service_name;
    initialAdminUsername = "admin";

    keys = {
      dbPassword = "keycloakdbpassword";
      initialAdminPassword = "keycloakinitialadmin";
    };

    logLevel = "INFO";
    hostname = "keycloak.${getDomain "KeycloakService"}";

    dbType = "postgres";
    dbDatabase = KeycloakPostgresDB.database;
    dbUsername = KeycloakPostgresDB.username;
    dbHost = {KeycloakPostgresDB}: KeycloakPostgresDB.target.properties.hostname;
    dbPort = (getTarget "KeycloakPostgresDB").containers.postgresql-database.port;

    inherit KeycloakPostgresDB;
  };
}
