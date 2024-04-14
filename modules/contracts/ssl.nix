{ lib, ... }:
rec {
  certs-paths = lib.types.submodule {
    freeformType = lib.types.anything;

    options = {
      cert = lib.mkOption {
        type = lib.types.path;
        description = "Path to the cert file.";
      };
      key = lib.mkOption {
        type = lib.types.path;
        description = "Path to the key file.";
      };
    };
  };
  cas = lib.types.submodule {
    freeformType = lib.types.anything;

    options = {
      paths = lib.mkOption {
        description = ''
          Paths where the files for the CA will be located.

          This option is the contract output of the `shb.certs.cas` SSL block.
        '';
        type = certs-paths;
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
    };
  };
  certs = lib.types.submodule {
    freeformType = lib.types.anything;

    options = {
      paths = lib.mkOption {
        description = ''
          Paths where the files for the certificate will be located.

          This option is the contract output of the `shb.certs.certs` SSL block.
        '';
        type = certs-paths;
      };

      systemdService = lib.mkOption {
        description = ''
          Systemd oneshot service used to generate the certificate. Ends with the `.service` suffix.

          Use this if downstream services must wait for the certificates to be generated before
          starting.
        '';
        type = lib.types.str;
        example = "cert-generator.service";
      };
    };
  };
}
