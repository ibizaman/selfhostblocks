{ stdenv
, pkgs
, lib
}:
{ realm
, domain
, roles ? {}
, clients ? {}
, users ? {}
, groups ? []
}:

with builtins;
with (pkgs.lib.attrsets);
let
  mkRole = k: v:
    let
      iscomposite = (length v) > 0;
    in {
      name = k;
      composite = if iscomposite then true else false;
    } // optionalAttrs iscomposite {
      composites = {
        realm = v;
      };
    };

  mkClientRole =
    let
      roles = config: config.roles or [];

      c = v:
        {
          name = v;
          clientRole = true;
        };
    in k: config: map c (roles config);

  mkGroup = name: {
    inherit name;
    path = "/${name}";
    attributes = {};
    realmRoles = [];
    clientRoles = {};
    subGroups = [];
  };

  mkClient = k: config:
    let
      url = "https://${k}.${domain}";
    in
      {
        clientId = k;
        rootUrl = url;
        clientAuthenticatorType = "client-secret";
        redirectUris = ["${url}/oauth2/callback"];
        webOrigins = [url];
        authorizationServicesEnabled = true;
        serviceAccountsEnabled = true;
        protocol = "openid-connect";
        publicClient = false;
        protocolMappers = [
          {
            name = "Client ID";
            protocol = "openid-connect";
            protocolMapper = "oidc-usersessionmodel-note-mapper";
            consentRequired = false;
            config = {
              "user.session.note" = "clientId";
              "id.token.claim" = "true";
              "access.token.claim" = "true";
              "claim.name" = "clientId";
              "jsonType.label" = "String";
            };
          }
          {
            name = "Client Host";
            protocol = "openid-connect";
            protocolMapper = "oidc-usersessionmodel-note-mapper";
            consentRequired = false;
            config = {
              "user.session.note" = "clientHost";
              "id.token.claim" = "true";
              "access.token.claim" = "true";
              "claim.name" = "clientHost";
              "jsonType.label" = "String";
            };
          }
          {
            name = "Client IP Address";
            protocol = "openid-connect";
            protocolMapper = "oidc-usersessionmodel-note-mapper";
            consentRequired = false;
            config = {
              "user.session.note" = "clientAddress";
              "id.token.claim" = "true";
              "access.token.claim" = "true";
              "claim.name" = "clientAddress";
              "jsonType.label" = "String";
            };
          }
          {
            name = "Audience";
            protocol = "openid-connect";
            protocolMapper = "oidc-audience-mapper";
            config = {
              "included.client.audience" = k;
              "id.token.claim" = "false";
              "access.token.claim" = "true";
              "included.custom.audience" = k;
            };
          }
          {
            name = "Group";
            protocol = "openid-connect";
            protocolMapper = "oidc-group-membership-mapper";
            config = {
              "full.path" = "true";
              "id.token.claim" = "true";
              "access.token.claim" = "true";
              "claim.name" = "groups";
              "userinfo.token.claim" = "true";
            };
          }
        ];
        authorizationSettings = {
          policyEnforcementMode = "ENFORCING";

          resources =
            let
              mkResource = name: uris: {
                inherit name;
                type = "urn:${k}:resources:${name}";
                ownerManagedAccess = false;
                inherit uris;
              };
            in
              mapAttrsToList mkResource (config.resourcesUris or {});

          policies =
            let
              mkPolicyRole = role: {
                id = role;
                required = true;
              };

              mkPolicy = name: roles: {
                name = "${concatStringsSep "," roles} has access";
                type = "role";
                logic = "POSITIVE";
                decisionStrategy = "UNANIMOUS";
                config = {
                  roles = toJSON (map mkPolicyRole roles);
                };
              };

              mkPermission = name: roles: resources: {
                name = "${concatStringsSep "," roles} has access to ${concatStringsSep "," resources}";
                type = "resource";
                logic = "POSITIVE";
                decisionStrategy = "UNANIMOUS";
                config = {
                  resources = toJSON resources;
                  applyPolicies = toJSON (map (r: "${concatStringsSep "," roles} has access") roles);
                };
              };
            in
              (mapAttrsToList (name: {roles, ...}: mkPolicy name roles) (config.access or {}))
              ++ (mapAttrsToList (name: {roles, resources}: mkPermission name roles resources) (config.access or {}));
        };
      };

  mkUser = k: config:
    {
      username = k;
      enabled = true;
      emailVerified = true;

      inherit (config) email firstName lastName;
    } // optionalAttrs (config ? "groups") {
      inherit (config) groups;
    } // optionalAttrs (config ? "roles") {
      realmRoles = config.roles;
    } // optionalAttrs (config ? "initialPassword") {
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
  enabled = true;

  clients = mapAttrsToList mkClient clients;

  roles = {
    realm = mapAttrsToList mkRole roles;
    client = mapAttrs mkClientRole clients;
  };

  groups = map mkGroup groups;

  users = mapAttrsToList mkUser users;
}
