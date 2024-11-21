{ pkgs, lib, ... }:
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
      passphrase.result = config.shb.hardcodedsecret.passphrase.result;
      repository = {
        path = repository;
        timerConfig = {
          OnCalendar = "00:00:00";
        };
      };
    };
    extraConfig = { username, config, ... }: {
      shb.hardcodedsecret.passphrase = {
        request = config.shb.restic.instances."mytest".settings.passphrase.request;
        settings.content = "passphrase";
      };
    };
  };

  restic_nonroot = contracts.test.backup {
    name = "restic_nonroot";
    username = "me";
    providerRoot = [ "shb" "restic" "instances" "mytest" ];
    modules = [
      ../../modules/blocks/restic.nix
      ../../modules/blocks/hardcodedsecret.nix
    ];
    settings = { repository, config, ... }: {
      enable = true;
      passphrase.result = config.shb.hardcodedsecret.passphrase.result;
      repository = {
        path = repository;
        timerConfig = {
          OnCalendar = "00:00:00";
        };
      };
    };
    extraConfig = { username, config, ... }: {
      shb.hardcodedsecret.passphrase = {
        request = config.shb.restic.instances."mytest".settings.passphrase.request;
        settings.content = "passphrase";
      };
    };
  };
}
