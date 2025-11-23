{ pkgs, lib, ... }:
let
  shb = (import ./default.nix { inherit pkgs lib; });
in
{
  _module.args.shb = shb // {
    test = pkgs.callPackage ../test/common.nix { };
    contracts = pkgs.callPackage ../modules/contracts { inherit shb; };
  };
}
