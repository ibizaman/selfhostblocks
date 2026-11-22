{ shb, pkgs, ... }:
let
  testFile = pkgs.callPackage ../../modules/contracts/backup/test.nix { inherit shb; };
in
{
  restic_root = testFile {
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
      { config, ... }:
      {
        enable = true;
        repository = {
          path = "/opt/repos/mytest";
          timerConfig = {
            OnCalendar = "00:00:00";
          };
        };
      };
    extraConfig =
      { username, config, ... }:
      {
        shb.hardcodedsecret.passphrase = config.shb.restic.instances."mytest".settings.passphrase // {
          settings.content = "passphrase";
        };
      };
  };

  restic_nonroot = testFile {
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
      { config, ... }:
      {
        enable = true;
        repository = {
          path = "/opt/repos/mytest";
          timerConfig = {
            OnCalendar = "00:00:00";
          };
        };
      };
    extraConfig =
      { username, config, ... }:
      {
        shb.hardcodedsecret.passphrase = config.shb.restic.instances."mytest".settings.passphrase // {
          settings.content = "passphrase";
        };
      };
  };

  borgbackup_root = testFile {
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
      { config, ... }:
      {
        enable = true;
        repository = {
          path = "/opt/repos/mytest";
          timerConfig = {
            OnCalendar = "00:00:00";
          };
        };
      };
    extraConfig =
      {
        username,
        config,
        hookPath,
        ...
      }:
      {
        shb.hardcodedsecret.passphrase = config.shb.borgbackup.instances."mytest".settings.passphrase // {
          settings.content = "passphrase";
        };
        systemd.services.borgbackup-job-mytest_opt_repos_mytest.serviceConfig.ReadWritePaths = [
          hookPath
        ];
      };
  };

  borgbackup_nonroot = testFile {
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
      { config, ... }:
      {
        enable = true;
        repository = {
          path = "/opt/repos/mytest";
          timerConfig = {
            OnCalendar = "00:00:00";
          };
        };
      };
    extraConfig =
      {
        username,
        config,
        hookPath,
        ...
      }:
      {
        shb.hardcodedsecret.passphrase = config.shb.borgbackup.instances."mytest".settings.passphrase // {
          settings.content = "passphrase";
        };
        systemd.services.borgbackup-job-mytest_opt_repos_mytest.serviceConfig.ReadWritePaths = [
          hookPath
        ];
      };
  };
}
