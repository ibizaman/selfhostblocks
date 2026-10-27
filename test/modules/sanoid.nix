{ pkgs, lib, ... }:
let
  eval =
    backup:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../../modules/blocks/sanoid.nix
        ../../modules/blocks/zfs.nix
        ({ config, ... }: {
          boot.isContainer = true;
          system.stateVersion = "25.11";
          services.sanoid.templates.test-only = { };
          shb.zfs.pools.testpool.datasets.test-only.path = "none";
          shb.sanoid.backup = backup config;
        })
      ];
    }).config;
  config = eval (config: {
    testjob = {
      request = config.shb.zfs.pools.testpool.datasets.test-only.datasetbackup.request;
      settings.useTemplate = [ "test-only" ];
    };
  });
  assertionsPass = config: lib.all (assertion: assertion.assertion) config.assertions;
in
{
  testSanoidDatasetRequest = {
    expected = {
      datasets = [ "testpool/test-only" ];
      template = [ "test-only" ];
      restoreScript = "sanoid-testjob-restore";
      backupService = "sanoid.service";
      valid = true;
    };
    expr = {
      datasets = lib.attrNames config.services.sanoid.datasets;
      template = config.services.sanoid.datasets."testpool/test-only".useTemplate;
      inherit (config.shb.sanoid.backup.testjob.result) restoreScript backupService;
      valid = assertionsPass config;
    };
  };

  testSanoidMissingDataset = {
    expected = false;
    expr = assertionsPass (
      eval (_: {
        testjob = { };
      })
    );
  };

  testSanoidDuplicateDatasets = {
    expected = false;
    expr = assertionsPass (
      eval (_: {
        testjob.request.dataset = "testpool/test-only";
        othertestjob.request.dataset = "testpool/test-only";
      })
    );
  };
}
