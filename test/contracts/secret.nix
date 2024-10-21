{ pkgs, ... }:
let
  contracts = pkgs.callPackage ../../modules/contracts {};
in
{
  hardcoded_root_root = contracts.test.secret {
    name = "hardcoded";
    modules = [ ../../modules/blocks/hardcodedsecret.nix ];
    configRoot = [ "shb" "hardcodedsecret" ];
    createContent = {
      content = "secretA";
    };
  };

  hardcoded_user_group = contracts.test.secret {
    name = "hardcoded";
    modules = [ ../../modules/blocks/hardcodedsecret.nix ];
    configRoot = [ "shb" "hardcodedsecret" ];
    createContent = {
      content = "secretA";
    };
    owner = "user";
    group = "group";
    mode = "640";
  };

  # TODO: how to do this?
  # sops = contracts.test.secret {
  #   name = "sops";
  #   configRoot = cfg: name: cfg.sops.secrets.${name};
  #   createContent = content: {
  #     sopsFile = ./secret/sops.yaml;
  #   };
  # };
}
