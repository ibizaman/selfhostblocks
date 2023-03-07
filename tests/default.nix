{ pkgs
, utils
}:

{
  unit = pkgs.callPackage ./unit { inherit utils; };
  integration = pkgs.callPackage ./integration { inherit utils; };
}
