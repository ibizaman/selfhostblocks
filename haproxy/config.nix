{ stdenv
, pkgs
, lib
, utils
}:
{ configDir ? "/etc/haproxy"
, configFile ? "haproxy.cfg"
, config
}:

with builtins;
with lib.attrsets;
with lib.lists;
with lib.strings;
let

  configcreator = pkgs.callPackage ./configcreator.nix {};

in

utils.mkConfigFile {
  name = configFile;
  dir = configDir;
  content = configcreator.render (configcreator.default config);
}
