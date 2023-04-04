{ infrastructure
, pkgs ? import <nixpkgs> {}
}:

with infrastructure;
let
  customPkgs = (pkgs.callPackage (./../../..) {}).customPkgs {
    inherit pkgs;
  };

  keycloak = customPkgs.keycloak {};
  vaultwarden = customPkgs.vaultwarden {};
in
{
  HaproxyService = [ machine1 ];

  KeycloakService = [ machine1 ];
  KeycloakCliService = [ machine1 ];

  KeycloakHaproxyService = [ machine1 ];
}
// keycloak.distribute [ machine1 ]
// vaultwarden.distribute [ machine1 ]
