{ pkgs, ... }:
let
  contracts = pkgs.callPackage ../../modules/contracts {};
in
{
  restic_root = contracts.test.backup {
    name = "restic_root";
    username = "root";
    providerRoot = [ "shb" "restic" "instances" "mytest" ];
    modules = [
      ../../modules/blocks/restic.nix
      ../../modules/blocks/hardcodedsecret.nix
    ];
    settings = { repository, config, ... }: {
      enable = true;
      passphrase.result.path = config.shb.hardcodedsecret.passphrase.path;
      repository = {
        path = repository;
        timerConfig = {
          OnCalendar = "00:00:00";
        };
      };
    };
    extraConfig = { username, ... }: {
      shb.hardcodedsecret.passphrase = {
        owner = username;
        content = "passphrase";
      };
    };
  };

  restic_me = contracts.test.backup {
    name = "restic_me";
    username = "me";
    providerRoot = [ "shb" "restic" "instances" "mytest" ];
    modules = [
      ../../modules/blocks/restic.nix
      ../../modules/blocks/hardcodedsecret.nix
    ];
    settings = { repository, config, ... }: {
      enable = true;
      passphrase.result.path = config.shb.hardcodedsecret.passphrase.path;
      repository = {
        path = repository;
        timerConfig = {
          OnCalendar = "00:00:00";
        };
      };
    };
    extraConfig = { username, ... }: {
      shb.hardcodedsecret.passphrase = {
        owner = username;
        content = "passphrase";
      };
    };
  };
}
