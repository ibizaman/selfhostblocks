{ pkgs, lib, ... }:
let
  pkgs' = pkgs;
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

      configWithTemplates = lib.shb.withReplacements userConfig;

      nonSecretConfigFile = pkgs.writeText "config.yaml.template" (lib.generators.toJSON {} configWithTemplates);

      replacements = lib.shb.getReplacements userConfig;

      replaceInTemplate = lib.shb.replaceSecretsScript {
        file = nonSecretConfigFile;
        resultPath = "/var/lib/config.yaml";
        inherit replacements;
      };

      replaceInTemplateJSON = lib.shb.replaceSecrets {
        inherit userConfig;
        resultPath = "/var/lib/config.json";
        generator = lib.shb.replaceSecretsFormatAdapter (pkgs.formats.json {});
      };

      replaceInTemplateJSONGen = lib.shb.replaceSecrets {
        inherit userConfig;
        resultPath = "/var/lib/config_gen.json";
        generator = lib.shb.replaceSecretsGeneratorAdapter (lib.generators.toJSON {});
      };

      replaceInTemplateXML = lib.shb.replaceSecrets {
        inherit userConfig;
        resultPath = "/var/lib/config.xml";
        generator = lib.shb.replaceSecretsFormatAdapter (lib.shb.formatXML {enclosingRoot = "Root";});
      };
    in
      lib.shb.runNixOSTest {
        name = "lib-template";
        nodes.machine = { config, pkgs, ... }:
          {
            imports = [
              (pkgs'.path + "/nixos/modules/profiles/headless.nix")
              (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
              {
                options = {
                  libtest.config = lib.mkOption {
                    type = lib.types.attrsOf (lib.types.oneOf [ lib.types.str lib.secretFileType ]);
                  };
                };
              }
            ];

            system.activationScripts = {
              libtest = replaceInTemplate;
              libtestJSON = replaceInTemplateJSON;
              libtestJSONGen = replaceInTemplateJSONGen;
              libtestXML = replaceInTemplateXML;
            };
          };

        testScript = { nodes, ... }: ''
        import json
        from collections import ChainMap
        from xml.etree import ElementTree

        start_all()
        machine.wait_for_file("/var/lib/config.yaml")
        machine.wait_for_file("/var/lib/config.json")
        machine.wait_for_file("/var/lib/config_gen.json")
        machine.wait_for_file("/var/lib/config.xml")

        def xml_to_dict_recursive(root):
            all_descendants = list(root)
            if len(all_descendants) == 0:
                return {root.tag: root.text}
            else:
                merged_dict = ChainMap(*map(xml_to_dict_recursive, all_descendants))
                return {root.tag: dict(merged_dict)}

        wantedConfig = json.loads('${lib.generators.toJSON {} wantedConfig}')

        with subtest("config"):
          print(machine.succeed("cat ${pkgs.writeText "replaceInTemplate" replaceInTemplate}"))

          gotConfig = machine.succeed("cat /var/lib/config.yaml")
          print(gotConfig)
          gotConfig = json.loads(gotConfig)

          if wantedConfig != gotConfig:
            raise Exception("\nwantedConfig: {}\n!= gotConfig: {}".format(wantedConfig, gotConfig))

        with subtest("config JSON Gen"):
          print(machine.succeed("cat ${pkgs.writeText "replaceInTemplateJSONGen" replaceInTemplateJSONGen}"))

          gotConfig = machine.succeed("cat /var/lib/config_gen.json")
          print(gotConfig)
          gotConfig = json.loads(gotConfig)

          if wantedConfig != gotConfig:
            raise Exception("\nwantedConfig:  {}\n!= gotConfig: {}".format(wantedConfig, gotConfig))

        with subtest("config JSON"):
          print(machine.succeed("cat ${pkgs.writeText "replaceInTemplateJSON" replaceInTemplateJSON}"))

          gotConfig = machine.succeed("cat /var/lib/config.json")
          print(gotConfig)
          gotConfig = json.loads(gotConfig)

          if wantedConfig != gotConfig:
            raise Exception("\nwantedConfig:  {}\n!= gotConfig: {}".format(wantedConfig, gotConfig))

        with subtest("config XML"):
          print(machine.succeed("cat ${pkgs.writeText "replaceInTemplateXML" replaceInTemplateXML}"))

          gotConfig = machine.succeed("cat /var/lib/config.xml")
          print(gotConfig)
          gotConfig = xml_to_dict_recursive(ElementTree.XML(gotConfig))['Root']

          if wantedConfig != gotConfig:
            raise Exception("\nwantedConfig:  {}\n!= gotConfig: {}".format(wantedConfig, gotConfig))
        '';
      };
}
