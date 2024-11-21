{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../../../test/common.nix {};

  inherit (lib) getAttrFromPath setAttrByPath;
  inherit (lib) mkIf;
in
  { name,
    configRoot,
    settingsCfg, # str -> attrset
    modules ? [],
    owner ? "root",
    group ? "root",
    mode ? "0400",
    restartUnits ? [ "myunit.service" ],
  }: pkgs.testers.runNixOSTest {
    name = "secret_${name}_${owner}_${group}_${mode}";

    nodes.machine = { config, ... }: {
      imports = ( testLib.baseImports pkgs' ) ++ modules;
      config = lib.mkMerge [
        (setAttrByPath configRoot {
          A = {
            request = {
              inherit owner group mode restartUnits;
            };
            settings = settingsCfg "secretA";
          };
        })
        (mkIf (owner != "root") {
          users.users.${owner}.isNormalUser = true;
        })
        (mkIf (group != "root") {
          users.groups.${group} = {};
        })
      ];
    };

    testScript = { nodes, ... }:
      let
        result = (getAttrFromPath configRoot nodes.machine)."A".result;
      in
        ''
          owner = machine.succeed("stat -c '%U' ${result.path}").strip()
          print(f"Got owner {owner}")
          if owner != "${owner}":
              raise Exception(f"Owner should be '${owner}' but got '{owner}'")

          group = machine.succeed("stat -c '%G' ${result.path}").strip()
          print(f"Got group {group}")
          if group != "${group}":
              raise Exception(f"Group should be '${group}' but got '{group}'")

          mode = str(int(machine.succeed("stat -c '%a' ${result.path}").strip()))
          print(f"Got mode {mode}")
          wantedMode = str(int("${mode}"))
          if mode != wantedMode:
              raise Exception(f"Mode should be '{wantedMode}' but got '{mode}'")

          content = machine.succeed("cat ${result.path}").strip()
          print(f"Got content {content}")
          if content != "secretA":
              raise Exception(f"Content should be 'secretA' but got '{content}'")
        '';
}
