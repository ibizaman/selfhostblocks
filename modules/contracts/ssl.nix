{ lib, ... }: {
  request = { ... }: {
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Main domain";
    };
    extraDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Extra domains";
      default = [ ];
    };
    group = lib.mkOption {
      type = lib.types.str;
      description = ''
        Unix group owning this certificate.
      '';
      default = "root";
      example = "nginx";
    };
  };
  result = { ... }: {
    cert = lib.mkOption {
      type = lib.types.path;
      description = "Path to the cert file.";
    };
    key = lib.mkOption {
      type = lib.types.path;
      description = "Path to the key file.";
    };
    systemdService = lib.mkOption {
      description = ''
        Systemd oneshot service used to generate the CA. Ends with the `.service` suffix.

        Use this if downstream services must wait for the certificates to be generated before
        starting.
      '';
      type = lib.types.str;
      example = "ca-generator.service";
    };
    reloadServices = lib.mkOption {
      description = ''
        The list of systemd services to call `systemctl try-reload-or-restart` on.
      '';
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "nginx.service" ];
    };
  };
}
