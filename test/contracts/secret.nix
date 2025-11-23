{ shb, ... }:
{
  hardcoded_root_root = shb.contracts.test.secret {
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

  hardcoded_user_group = shb.contracts.test.secret {
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
  # sops = shb.contracts.test.secret {
  #   name = "sops";
  #   configRoot = cfg: name: cfg.sops.secrets.${name};
  #   createContent = content: {
  #     sopsFile = ./secret/sops.yaml;
  #   };
  # };
}
