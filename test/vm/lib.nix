{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  shblib = pkgs.callPackage ../../lib {};
in
{
  template =
    let
      aSecret = pkgs.writeText "a-secret.txt" "Secret of A";
      bSecret = pkgs.writeText "b-secret.txt" "Secret of B";
      userConfig = {
        a.a.source = aSecret;
        b.source = bSecret;
        b.transform = v: "prefix-${v}-suffix";
        c = "not secret C";
        d.d = "not secret D";
      };

      wantedConfig = {
        a.a = "Secret of A";
        b = "prefix-Secret of B-suffix";
        c = "not secret C";
        d.d = "not secret D";
      };

      configWithTemplates = shblib.withReplacements userConfig;

      nonSecretConfigFile = pkgs.writeText "config.yaml.template" (lib.generators.toJSON {} configWithTemplates);

      replacements = shblib.getReplacements userConfig;

      replaceInTemplate = shblib.replaceSecretsScript {
        file = nonSecretConfigFile;
        resultPath = "/var/lib/config.yaml";
        inherit replacements;
      };

      replaceInTemplate2 = shblib.replaceSecrets {
        inherit userConfig;
        resultPath = "/var/lib/config2.yaml";
        generator = lib.generators.toJSON {};
      };
    in
      pkgs.nixosTest {
        name = "lib-template";
        nodes.machine = { config, pkgs, ... }:
          {
            imports = [
              (pkgs'.path + "/nixos/modules/profiles/minimal.nix")
              (pkgs'.path + "/nixos/modules/profiles/headless.nix")
              (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
              {
                options = {
                  libtest.config = lib.mkOption {
                    type = lib.types.attrsOf (lib.types.oneOf [ lib.types.str shblib.secretFileType ]);
                  };
                };
              }
            ];

            system.activationScripts = {
              libtest = replaceInTemplate;
              libtest2 = replaceInTemplate2;
            };
          };

        testScript = { nodes, ... }: ''
        import json
        start_all()

        wantedConfig = json.loads('${lib.generators.toJSON {} wantedConfig}')
        gotConfig = json.loads(machine.succeed("cat /var/lib/config.yaml"))
        gotConfig2 = json.loads(machine.succeed("cat /var/lib/config2.yaml"))

        # For debugging purpose
        print(machine.succeed("cat ${pkgs.writeText "replaceInTemplate" replaceInTemplate}"))
        print(machine.succeed("cat ${pkgs.writeText "replaceInTemplate2" replaceInTemplate2}"))

        if wantedConfig != gotConfig:
          raise Exception("\nwantedConfig: {}\n!= gotConfig: {}".format(wantedConfig, gotConfig))

        if wantedConfig != gotConfig2:
          raise Exception("\nwantedConfig:  {}\n!= gotConfig2: {}".format(wantedConfig, gotConfig))
        '';
      };
}
