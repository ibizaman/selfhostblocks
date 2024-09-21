{ lib, ... }:
lib.types.submodule {
  freeformType = lib.types.anything;

  options = {
    mode = lib.mkOption {
      description = ''
        Mode of the secret file.
      '';
      type = lib.types.str;
      default = "0400";
    };

    owner = lib.mkOption {
      description = ''
        Linux user owning the secret file.
      '';
      type = lib.types.str;
      default = "root";
    };

    group = lib.mkOption {
      description = ''
        Linux group owning the secret file.
      '';
      type = lib.types.str;
      default = "root";
    };

    restartUnits = lib.mkOption {
      description = ''
        Systemd units to restart after the secret is updated.
      '';
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };
}
