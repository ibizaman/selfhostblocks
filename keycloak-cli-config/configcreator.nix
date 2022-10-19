{ stdenv
, pkgs
, lib
}:
{ realm
, domain
, roles ? {}
, clients ? {}
, users ? {}
}:

with builtins;
with (pkgs.lib.attrsets);
let
  mkRole = k: v:
    let
      iscomposite = (length v) > 0;
    in {
      name = k;
      composite = if iscomposite then "true" else "false";
    } // optionalAttrs iscomposite {
      composites = {
        realm = v;
      };
    };

  mkClientRole =
    let
      roles = config:
        if (hasAttr "roles" config)
        then config.roles
        else [];

      c = v:
        {
          name = v;
          clientRole = "true";
        };
    in k: config: map c (roles config);

  mkClient = k: config:
    let
      url = "https://${k}.${domain}";
    in
      {
        clientId = k;
        rootUrl = url;
        clientAuthenticatorType = "client-secret";
        redirectUris = ["${url}/*"];
        webOrigins = [url];
        authorizationServicesEnabled = "true";
        serviceAccountsEnabled = "true";
        protocol = "openid-connect";
        publicClient = "false";
      };

  mkUser = k: config:
    {
      username = k;
      enabled = "true";

      inherit (config) email firstName lastName realmRoles;
    } // optionalAttrs (hasAttr "initialPassword" config && config.initialPassword) {
      credentials = [
        {
          type = "password";
          userLabel = "initial";
          value = "$(keycloak.users.${k}.password)";
        }
      ];
    };

in
{
  inherit realm;
  id = realm;
  enabled = "true";

  clients = mapAttrsToList mkClient clients;

  roles = {
    realm = mapAttrsToList mkRole roles;
    client = mapAttrs mkClientRole clients;
  };

  users = mapAttrsToList mkUser users;
}
