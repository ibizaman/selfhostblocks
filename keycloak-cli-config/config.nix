{ stdenv
, pkgs
, lib
, utils
}:
{ configDir ? "/etc/keycloak-cli-config"
, configFile ? "config.json"
, config ? {}
}:

utils.mkConfigFile {
  name = configFile;
  dir = configDir;
  content = builtins.toJSON config;
}
