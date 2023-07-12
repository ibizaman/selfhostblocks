# to run these tests:
# nix-instantiate --eval --strict . -A tests.keycloak

{ lib
, stdenv
, pkgs
}:

let
  configcreator = pkgs.callPackage ./../../keycloak-cli-config/configcreator.nix {};

  # Taken from https://github.com/NixOS/nixpkgs/blob/master/lib/attrsets.nix
  updateManyAttrsByPath =
    with builtins;
    with lib.lists;
    let
    # When recursing into attributes, instead of updating the `path` of each
    # update using `tail`, which needs to allocate an entirely new list,
    # we just pass a prefix length to use and make sure to only look at the
    # path without the prefix length, so that we can reuse the original list
    # entries.
    go = prefixLength: hasValue: value: updates:
      let
        # Splits updates into ones on this level (split.right)
        # And ones on levels further down (split.wrong)
        split = partition (el: length el.path == prefixLength) updates;

        # Groups updates on further down levels into the attributes they modify
        nested = groupBy (el: elemAt el.path prefixLength) split.wrong;

        # Applies only nested modification to the input value
        withNestedMods =
          # Return the value directly if we don't have any nested modifications
          if split.wrong == [] then
            if hasValue then value
            else
              # Throw an error if there is no value. This `head` call here is
              # safe, but only in this branch since `go` could only be called
              # with `hasValue == false` for nested updates, in which case
              # it's also always called with at least one update
              let updatePath = (head split.right).path; in
              throw
              ( "updateManyAttrsByPath: Path '${showAttrPath updatePath}' does "
              + "not exist in the given value, but the first update to this "
              + "path tries to access the existing value.")
          else
            # If there are nested modifications, try to apply them to the value
            if ! hasValue then
              # But if we don't have a value, just use an empty attribute set
              # as the value, but simplify the code a bit
              mapAttrs (name: go (prefixLength + 1) false null) nested
            else if isAttrs value then
              # If we do have a value and it's an attribute set, override it
              # with the nested modifications
              value //
              mapAttrs (name: go (prefixLength + 1) (value ? ${name}) value.${name}) nested
            else
              # However if it's not an attribute set, we can't apply the nested
              # modifications, throw an error
              let updatePath = (head split.wrong).path; in
              throw
              ( "updateManyAttrsByPath: Path '${showAttrPath updatePath}' needs to "
              + "be updated, but path '${showAttrPath (take prefixLength updatePath)}' "
              + "of the given value is not an attribute set, so we can't "
              + "update an attribute inside of it.");

        # We get the final result by applying all the updates on this level
        # after having applied all the nested updates
        # We use foldl instead of foldl' so that in case of multiple updates,
        # intermediate values aren't evaluated if not needed
      in foldl (acc: el: el.update acc) withNestedMods split.right;

  in updates: value: go 0 true value updates;
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
