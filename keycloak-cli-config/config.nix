{ stdenv
, pkgs
, lib
, utils
}:
{ configDir ? "/etc/keycloak-cli-config"
, configFile ? "config.json"
, realm
, domain
, roles ? {}
, clients ? {}
, users ? {}
}:

let
  configcreator = pkgs.callPackage ./configcreator.nix {};
in

utils.mkConfigFile {
  name = configFile;
  dir = configDir;
  content = builtins.toJSON (configcreator {
    inherit realm domain roles clients users;
  });
}
