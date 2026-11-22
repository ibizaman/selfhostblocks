{
  pkgs,
  lib,
  shbContracts,
  ...
}:
let
  shb = (import ./default.nix { inherit pkgs lib; });
in
{
  imports = [
    ../modules/contracts
  ];
  _module.args.shb = shb // {
    test = pkgs.callPackage ../test/common.nix { };
    contracts = shbContracts;
  };
}
