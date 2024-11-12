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
    ];
    settings = repository: {
      enable = true;
      passphraseFile = toString (pkgs.writeText "passphrase" "PassPhrase");
      repository = {
        path = repository;
        timerConfig = {
          OnCalendar = "00:00:00";
        };
      };
    };
  };

  restic_me = contracts.test.backup {
    name = "restic_me";
    username = "me";
    providerRoot = [ "shb" "restic" "instances" "mytest" ];
    modules = [
      ../../modules/blocks/restic.nix
    ];
    settings = repository: {
      enable = true;
      passphraseFile = toString (pkgs.writeText "passphrase" "PassPhrase");
      repository = {
        path = repository;
        timerConfig = {
          OnCalendar = "00:00:00";
        };
      };
    };
  };
}
