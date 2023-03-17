# to run these tests:
# nix-instantiate --eval --strict . -A tests.keycloak-cli-config

{ lib
, stdenv
, pkgs
}:

let
  configcreator = pkgs.callPackage ./../../keycloak-cli-config/configcreator.nix {};

  default_config = {
    realm = "myrealm";
    domain = "mydomain.com";
  };

  keep_fields = fields:
    lib.filterAttrs (n: v: lib.any (n_: n_ == n) fields);
in

lib.runTests {
  testDefault = {
    expr = configcreator default_config;

    expected = {
      id = "myrealm";
      realm = "myrealm";
      enabled = true;
      clients = [];
      roles = {
        realm = [];
        client = {};
      };
      groups = [];
      users = [];
    };
  };

  testUsers = {
    expr = (configcreator (default_config // {
      users = {
        me = {
          email = "me@mydomain.com";
          firstName = "me";
          lastName = "stillme";
        };
      };
    })).users;

    expected = [
      {
        username = "me";
        enabled = true;
        email = "me@mydomain.com";
        emailVerified = true;
        firstName = "me";
        lastName = "stillme";
      }
    ];
  };

  testUsersWithGroups = {
    expr = (configcreator (default_config // {
      users = {
        me = {
          email = "me@mydomain.com";
          firstName = "me";
          lastName = "stillme";
          groups = [ "MyGroup" ];
        };
      };
    })).users;

    expected = [
      {
        username = "me";
        enabled = true;
        email = "me@mydomain.com";
        emailVerified = true;
        firstName = "me";
        lastName = "stillme";
        groups = [ "MyGroup" ];
      }
    ];
  };

  testUsersWithRoles = {
    expr = (configcreator (default_config // {
      users = {
        me = {
          email = "me@mydomain.com";
          firstName = "me";
          lastName = "stillme";
          roles = [ "MyRole" ];
        };
      };
    })).users;

    expected = [
      {
        username = "me";
        enabled = true;
        email = "me@mydomain.com";
        emailVerified = true;
        firstName = "me";
        lastName = "stillme";
        realmRoles = [ "MyRole" ];
      }
    ];
  };

  testUsersWithInitialPassword = {
    expr = (configcreator (default_config // {
      users = {
        me = {
          email = "me@mydomain.com";
          firstName = "me";
          lastName = "stillme";
          initialPassword = true;
        };
      };
    })).users;

    expected = [
      {
        username = "me";
        enabled = true;
        email = "me@mydomain.com";
        emailVerified = true;
        firstName = "me";
        lastName = "stillme";
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

  testGroups = {
    expr = (configcreator (default_config // {
      groups = [ "MyGroup" ];
    })).groups;

    expected = [
      {
        name = "MyGroup";
        path = "/MyGroup";
        attributes = {};
        realmRoles = [];
        clientRoles = {};
        subGroups = [];
      }
    ];
  };

  testRealmRoles = {
    expr = (configcreator (default_config // {
      roles = {
        A = [ "B" ];
        B = [ ];
      };
    })).roles;

    expected = {
      client = {};
      realm = [
        {
          name = "A";
          composite = true;
          composites = {
            realm = [ "B" ];
          };
        }
        {
          name = "B";
          composite = false;
        }
      ];
    };
  };

  testClientRoles = {
    expr = (configcreator (default_config // {
      clients = {
        clientA = {
          roles = [ "cA" ];
        };
      };
    })).roles;

    expected = {
      client = {
        clientA = [
          {
            name = "cA";
            clientRole = true;
          }
        ];
      };
      realm = [];
    };
  };

  testClient = {
    expr = map (keep_fields [
      "clientId"
      "rootUrl"
      "redirectUris"
      "webOrigins"
      "authorizationSettings"
    ]) (configcreator (default_config // {
      clients = {
        clientA = {};
      };
    })).clients;
    expected = [
      {
        clientId = "clientA";
        rootUrl = "https://clientA.mydomain.com";
        redirectUris = ["https://clientA.mydomain.com/oauth2/callback"];
        webOrigins = ["https://clientA.mydomain.com"];
        authorizationSettings = {
          policyEnforcementMode = "ENFORCING";
          resources = [];
          policies = [];
        };
      }
    ];
  };

  testClientAuthorization = with builtins; {
    expr = (head (configcreator (default_config // {
      clients = {
        clientA = {
          resourcesUris = {
            adminPath = ["/admin/*"];
            userPath = ["/*"];
          };
          access = {
            admin = {
              roles = [ "admin" ];
              resources = [ "adminPath" ];
            };
            user = {
              roles = [ "user" ];
              resources = [ "userPath" ];
            };
          };
        };
      };
    })).clients).authorizationSettings;
    expected = {
      policyEnforcementMode = "ENFORCING";
      resources = [
        {
          name = "adminPath";
          type = "urn:clientA:resources:adminPath";
          ownerManagedAccess = false;
          uris = ["/admin/*"];
        }
        {
          name = "userPath";
          type = "urn:clientA:resources:userPath";
          ownerManagedAccess = false;
          uris = ["/*"];
        }
      ];
      policies = [
        {
          name = "admin has access";
          type = "role";
          logic = "POSITIVE";
          decisionStrategy = "UNANIMOUS";
          config = {
            roles = ''[{"id":"admin","required":true}]'';
          };
        }
        {
          name = "user has access";
          type = "role";
          logic = "POSITIVE";
          decisionStrategy = "UNANIMOUS";
          config = {
            roles = ''[{"id":"user","required":true}]'';
          };
        }
        {
          name = "admin has access to adminPath";
          type = "resource";
          logic = "POSITIVE";
          decisionStrategy = "UNANIMOUS";
          config = {
            resources = ''["adminPath"]'';
            applyPolicies = ''["admin has access"]'';
          };
        }
        {
          name = "user has access to userPath";
          type = "resource";
          logic = "POSITIVE";
          decisionStrategy = "UNANIMOUS";
          config = {
            resources = ''["userPath"]'';
            applyPolicies = ''["user has access"]'';
          };
        }
      ];
    };
  };

  testClientAudience =
    let
      audienceProtocolMapper = config:
        with builtins;
        let
          protocolMappers = (head config.clients).protocolMappers;
          protocolMapperByName = name: protocolMappers: head (filter (x: x.name == name) protocolMappers);
        in
        protocolMapperByName "Audience" protocolMappers;
    in
      {
        expr = audienceProtocolMapper (configcreator (default_config // {
          clients = {
            clientA = {};
          };
        }));
        expected = {
          name = "Audience";
          protocol = "openid-connect";
          protocolMapper = "oidc-audience-mapper";
          config = {
            "included.client.audience" = "clientA";
            "id.token.claim" = "false";
            "access.token.claim" = "true";
            "included.custom.audience" = "clientA";
          };
        };
      };
}
