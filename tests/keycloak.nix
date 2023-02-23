# to run these tests:
# nix-instantiate --eval --strict . -A tests.keycloak

{ lib
, stdenv
, pkgs
}:

let
  configcreator = pkgs.callPackage ./../keycloak-cli-config/configcreator.nix {};
in

with lib.attrsets;
lib.runTests {
  testConfigEmpty = {
    expr = configcreator {
      realm = "myrealm";
      domain = "domain.com";
    };
    expected = {
      id = "myrealm";
      realm = "myrealm";
      enabled = true;
      clients = [];
      groups = [];
      roles = {
        client = {};
        realm = [];
      };
      users = [];
    };
  };

  testConfigRole = {
    expr = configcreator {
      realm = "myrealm";
      domain = "domain.com";
      roles = {
        user = [];
        admin = ["user"];
      };
    };
    expected = {
      id = "myrealm";
      realm = "myrealm";
      enabled = true;
      clients = [];
      groups = [];
      roles = {
        realm = [
          {
            name = "admin";
            composite = true;
            composites = {
              realm = ["user"];
            };
          }
          {
            name = "user";
            composite = false;
          }
        ];
        client = {};
      };
      users = [];
    };
  };

  testConfigClient = {
    expr =
      let
        c = configcreator {
          realm = "myrealm";
          domain = "domain.com";
          clients = {
            myclient = {};
            myclient2 = {
              roles = ["uma"];
            };
          };
        };
      in
        updateManyAttrsByPath [
          {
            path = [ "clients" ];
            # We don't care about the value of the protocolMappers
            # field because its value is hardcoded.
            update = clients: map (filterAttrs (n: v: n != "protocolMappers")) clients;
          }
        ] c;
    expected = {
      id = "myrealm";
      realm = "myrealm";
      enabled = true;
      clients = [
        {
          clientId = "myclient";
          rootUrl = "https://myclient.domain.com";
          clientAuthenticatorType = "client-secret";
          redirectUris = [
            "https://myclient.domain.com/oauth2/callback"
          ];
          webOrigins = [
            "https://myclient.domain.com"
          ];
          authorizationServicesEnabled = true;
          serviceAccountsEnabled = true;
          protocol = "openid-connect";
          publicClient = false;
          authorizationSettings = {
            policyEnforcementMode = "ENFORCING";
            resources = [];
            policies = [];
          };
        }
        {
          clientId = "myclient2";
          rootUrl = "https://myclient2.domain.com";
          clientAuthenticatorType = "client-secret";
          redirectUris = [
            "https://myclient2.domain.com/oauth2/callback"
          ];
          webOrigins = [
            "https://myclient2.domain.com"
          ];
          authorizationServicesEnabled = true;
          serviceAccountsEnabled = true;
          protocol = "openid-connect";
          publicClient = false;
          authorizationSettings = {
            policyEnforcementMode = "ENFORCING";
            resources = [];
            policies = [];
          };
        }
      ];
      groups = [];
      roles = {
        client = {
          myclient = [];
          myclient2 = [
            {
              name = "uma";
              clientRole = true;
            }
          ];
        };
        realm = [];
      };
      users = [];
    };
  };

  testConfigUser = {
    expr = configcreator {
      realm = "myrealm";
      domain = "domain.com";
      users = {
        me = {
          email = "me@me.com";
          firstName = null;
          lastName = "Me";
          realmRoles = [ "role" ];
        };
      };
    };
    expected = {
      id = "myrealm";
      realm = "myrealm";
      enabled = true;
      clients = [];
      groups = [];
      roles = {
        client = {};
        realm = [];
      };
      users = [
        {
          enabled = true;
          username = "me";
          email = "me@me.com";
          emailVerified = true;
          firstName = null;
          lastName = "Me";
        }
      ];
    };
  };

  testConfigUserInitialPassword = {
    expr = configcreator {
      realm = "myrealm";
      domain = "domain.com";
      users = {
        me = {
          email = "me@me.com";
          firstName = null;
          lastName = "Me";
          initialPassword = true;
        };
      };
    };
    expected = {
      id = "myrealm";
      realm = "myrealm";
      enabled = true;
      clients = [];
      groups = [];
      roles = {
        client = {};
        realm = [];
      };
      users = [
        {
          enabled = true;
          username = "me";
          email = "me@me.com";
          emailVerified = true;
          firstName = null;
          lastName = "Me";
          credentials = [
            {
              type = "password";
              userLabel = "initial";
              value = "$(keycloak.users.me.password)";
            }
          ];
        }
      ];
    };
  };
}
