{ pkgs, ... }:
{
  testZfsDatasetBackupNames = {
    expected = [
      "testpool/test-only"
      "otherpool/test-only"
      "testpool/safe/test-only"
    ];
    expr =
      let
        pools =
          (import "${pkgs.path}/nixos/lib/eval-config.nix" {
            system = pkgs.stdenv.hostPlatform.system;
            modules = [
              ../../modules/blocks/zfs.nix
              {
                shb.zfs.pools = {
                  testpool.datasets.test-only.path = "none";
                  otherpool.datasets.test-only.path = "none";
                  testpool.datasets."safe/test-only".path = "none";
                };
              }
            ];
          }).config.shb.zfs.pools;
      in
      [
        pools.testpool.datasets.test-only.datasetbackup.request.dataset
        pools.otherpool.datasets.test-only.datasetbackup.request.dataset
        pools.testpool.datasets."safe/test-only".datasetbackup.request.dataset
      ];
  };
}
