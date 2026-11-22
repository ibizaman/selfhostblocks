{ shb, pkgs, ... }:
let
  testFile = pkgs.callPackage ../../modules/contracts/secret/test.nix { inherit shb; };
in
{
  hardcoded_root_root = testFile {
    name = "hardcoded";
    modules = [ ../../modules/blocks/hardcodedsecret.nix ];
    configRoot = [
      "shb"
      "hardcodedsecret"
    ];
    settingsCfg = secret: {
      content = secret;
    };
  };

  hardcoded_user_group = testFile {
    name = "hardcoded";
    modules = [ ../../modules/blocks/hardcodedsecret.nix ];
    configRoot = [
      "shb"
      "hardcodedsecret"
    ];
    settingsCfg = secret: {
      content = secret;
    };
    owner = "user";
    group = "group";
    mode = "640";
  };

  # TODO: how to do this?
  # sops = testFile {
  #   name = "sops";
  #   configRoot = cfg: name: cfg.sops.secrets.${name};
  #   createContent = content: {
  #     sopsFile = ./secret/sops.yaml;
  #   };
  # };
}
