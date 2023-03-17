{ pkgs
, utils
}:
rec {
  all = [keycloak];

  keycloak = pkgs.callPackage ./keycloak.nix {};
}
