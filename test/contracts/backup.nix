{ shb, ... }:
{
  restic_root = shb.contracts.test.backup {
    name = "restic_root";
    username = "root";
    providerRoot = [
      "shb"
      "restic"
      "instances"
      "mytest"
    ];
    modules = [
      ../../modules/blocks/restic.nix
      ../../modules/blocks/hardcodedsecret.nix
    ];
    settings =
      { repository, config, ... }:
      {
        enable = true;
        passphrase.result = config.shb.hardcodedsecret.passphrase.result;
        repository = {
          path = repository;
          timerConfig = {
            OnCalendar = "00:00:00";
          };
        };
      };
    extraConfig =
      { username, config, ... }:
      {
        shb.hardcodedsecret.passphrase = {
          request = config.shb.restic.instances."mytest".settings.passphrase.request;
          settings.content = "passphrase";
        };
      };
  };

  restic_nonroot = shb.contracts.test.backup {
    name = "restic_nonroot";
    username = "me";
    providerRoot = [
      "shb"
      "restic"
      "instances"
      "mytest"
    ];
    modules = [
      ../../modules/blocks/restic.nix
      ../../modules/blocks/hardcodedsecret.nix
    ];
    settings =
      { repository, config, ... }:
      {
        enable = true;
        passphrase.result = config.shb.hardcodedsecret.passphrase.result;
        repository = {
          path = repository;
          timerConfig = {
            OnCalendar = "00:00:00";
          };
        };
      };
    extraConfig =
      { username, config, ... }:
      {
        shb.hardcodedsecret.passphrase = {
          request = config.shb.restic.instances."mytest".settings.passphrase.request;
          settings.content = "passphrase";
        };
      };
  };

  borgbackup_root = shb.contracts.test.backup {
    name = "borgbackup_root";
    username = "root";
    providerRoot = [
      "shb"
      "borgbackup"
      "instances"
      "mytest"
    ];
    modules = [
      ../../modules/blocks/borgbackup.nix
      ../../modules/blocks/hardcodedsecret.nix
    ];
    settings =
      { repository, config, ... }:
      {
        enable = true;
        passphrase.result = config.shb.hardcodedsecret.passphrase.result;
        repository = {
          path = repository;
          timerConfig = {
            OnCalendar = "00:00:00";
          };
        };
      };
    extraConfig =
      { username, config, ... }:
      {
        shb.hardcodedsecret.passphrase = {
          request = config.shb.borgbackup.instances."mytest".settings.passphrase.request;
          settings.content = "passphrase";
        };
      };
  };

  borgbackup_nonroot = shb.contracts.test.backup {
    name = "borgbackup_nonroot";
    username = "me";
    providerRoot = [
      "shb"
      "borgbackup"
      "instances"
      "mytest"
    ];
    modules = [
      ../../modules/blocks/borgbackup.nix
      ../../modules/blocks/hardcodedsecret.nix
    ];
    settings =
      { repository, config, ... }:
      {
        enable = true;
        passphrase.result = config.shb.hardcodedsecret.passphrase.result;
        repository = {
          path = repository;
          timerConfig = {
            OnCalendar = "00:00:00";
          };
        };
      };
    extraConfig =
      { username, config, ... }:
      {
        shb.hardcodedsecret.passphrase = {
          request = config.shb.borgbackup.instances."mytest".settings.passphrase.request;
          settings.content = "passphrase";
        };
      };
  };
}
