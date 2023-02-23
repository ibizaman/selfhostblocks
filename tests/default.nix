# to run all tests:
# nix-instantiate --eval --strict . -A tests

{ pkgs
, utils
}:

{
  haproxy = pkgs.callPackage ./haproxy.nix { inherit utils; };
  keycloak = pkgs.callPackage ./keycloak.nix {};
  keycloak-cli-config = pkgs.callPackage ./keycloak-cli-config.nix {};
}
