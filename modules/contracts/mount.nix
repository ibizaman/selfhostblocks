{ lib, ... }:
lib.types.submodule {
  freeformType = lib.types.anything;

  options = {
    path = lib.mkOption {
      type = lib.types.str;
      description = "Path to be mounted.";
    };
  };
}
