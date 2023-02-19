{ customPkgs
, pkgs
, utils
}:
{ serviceName ? "Keycloak"
, subdomain ? "keycloak"

, database ?
  {
    name = subdomain;
    username = "keycloak";
    # TODO: use passwordFile
    password = "keycloak";
  }
}:
rec {
  inherit subdomain;
  inherit database;

  db = customPkgs.mkPostgresDB {
    name = "KeycloakPostgresDB";
    database = database.name;
    username = database.username;
    # TODO: use passwordFile
    password = database.password;
  };

  services = {
    ${db.name} = db;
  };

  distribute = on: {
    ${db.name} = on;
  };
}
