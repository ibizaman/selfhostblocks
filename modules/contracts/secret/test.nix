{
  pkgs,
  lib,
  shb,
}:
let
  inherit (lib) getAttrFromPath setAttrByPath;
  inherit (lib) mkIf;
in
{
  name,
  configRoot,
  settingsCfg, # str -> attrset
  modules ? [ ],
  owner ? "root",
  group ? "root",
  mode ? "0400",
  restartUnits ? [ "myunit.service" ],
}:
shb.test.runNixOSTest {
  name = "secret_${name}_${owner}_${group}_${mode}";

  nodes.machine =
    { config, ... }:
    {
      imports = [
        shb.test.baseImports
      ]
      ++ modules
      ++ [
        ({ shb, lib, ... }: {
          options.shb.tests.secret.requester = lib.mkOption {
            default = { };
            type = shb.contracts.secret.mkRequester {
              inherit
                owner
                group
                mode
                restartUnits
                ;
            };
          };
        })
      ];
      config = lib.mkMerge [
        (setAttrByPath (configRoot ++ [ "A" ]) (
          config.shb.tests.secret.requester
          // {
            settings = settingsCfg "secretA";
          }
        ))
        (mkIf (owner != "root") {
          users.users.${owner}.isNormalUser = true;
        })
        (mkIf (group != "root") {
          users.groups.${group} = { };
        })
      ];
    };

  testScript =
    { nodes, ... }:
    let
      result = nodes.machine.shb.tests.secret.requester.result;
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
