{ config, pkgs, lib, ... }:

let
  cfg = config.shb.certs;

  contracts = pkgs.callPackage ../contracts {};
in
{
  options.shb.certs = {
    systemdService = lib.mkOption {
      description = ''
        Systemd oneshot service used to generate the Certificate Authority bundle.
      '';
      type = lib.types.str;
      default = "shb-ca-bundle.service";
    };
    cas.selfsigned = lib.mkOption {
      description = "Generate a self-signed Certificate Authority.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule ({ config, ...}: {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = ''
              Certificate Authority Name. You can put what you want here, it will be displayed by the
              browser.
            '';
            default = "Self Host Blocks Certificate";
          };

          paths = lib.mkOption {
            description = ''
              Paths where CA certs will be located.

              This option is the contract output of the `shb.certs.cas` SSL block.
            '';
            type = contracts.ssl.certs-paths;
            default = rec {
              key = "/var/lib/certs/cas/${config._module.args.name}.key";
              cert = "/var/lib/certs/cas/${config._module.args.name}.cert";
            };
          };

          systemdService = lib.mkOption {
            description = "Systemd oneshot service used to generate the certs.";
            type = lib.types.str;
            default = "shb-certs-ca-${config._module.args.name}.service";
          };
        };
      }));
    };
    certs.selfsigned = lib.mkOption {
      description = "Generate self-signed certificates signed by a Certificate Authority.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        options = {
          ca = lib.mkOption {
            type = lib.types.nullOr contracts.ssl.cas;
            description = ''
              CA used to generate this certificate. Only used for self-signed.

              This contract input takes the contract output of the `shb.certs.cas` SSL block.
            '';
            default = null;
          };

          domain = lib.mkOption {
            type = lib.types.str;
            description = ''
              Domain to generate a certificate for. This can be a wildcard domain like
              `*.example.com`.
            '';
            example = "example.com";
          };

          extraDomains = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = ''
              Other domains to generate a certificate for.
            '';
            default = [];
            example = lib.literalExpression ''
              [
                "sub1.example.com"
                "sub2.example.com"
              ]
            '';
          };

          paths = lib.mkOption {
            description = ''
              Paths where certs will be located.

              This option is the contract output of the `shb.certs.certs` SSL block.
            '';
            type = contracts.ssl.certs-paths;
            default = rec {
              key = "/var/lib/certs/selfsigned/${config._module.args.name}.key";
              cert = "/var/lib/certs/selfsigned/${config._module.args.name}.cert";
            };
          };

          systemdService = lib.mkOption {
            description = "Systemd oneshot service used to generate the certs.";
            type = lib.types.str;
            default = "shb-certs-cert-selfsigned-${config._module.args.name}.service";
          };
        };
      }));
    };

    certs.letsencrypt = lib.mkOption {
      description = "Generate certificates signed by [Let's Encrypt](https://letsencrypt.org/).";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        options = {
          domain = lib.mkOption {
            type = lib.types.str;
            description = ''
              Domain to generate a certificate for. This can be a wildcard domain like
              `*.example.com`.
            '';
            example = "example.com";
          };

          extraDomains = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = ''
              Other domains to generate a certificate for.
            '';
            default = [];
            example = lib.literalExpression ''
              [
                "sub1.example.com"
                "sub2.example.com"
              ]
            '';
          };

          paths = lib.mkOption {
            description = ''
              Paths where certs will be located.

              This option is the contract output of the `shb.certs.certs` SSL block.
            '';
            type = contracts.ssl.certs-paths;
            default = {
              key = "/var/lib/acme/${config._module.args.name}/key.pem";
              cert = "/var/lib/acme/${config._module.args.name}/cert.pem";
            };
          };

          systemdService = lib.mkOption {
            description = "Systemd oneshot service used to generate the certs.";
            type = lib.types.str;
            default = "shb-certs-cert-letsencrypt-${config._module.args.name}.service";
          };

          dnsProvider = lib.mkOption {
            description = "DNS provider to use. See https://go-acme.github.io/lego/dns/ for the list of supported providers.";
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "linode";
          };

          dnsResolver = lib.mkOption {
            description = "IP of a DNS server used to resolve hostnames.";
            type = lib.types.str;
            default = "8.8.8.8";
          };

          credentialsFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            description = ''
            Credentials file location for the chosen DNS provider.

            The content of this file must expose environment variables as written in the
            [documentation](https://go-acme.github.io/lego/dns/) of each DNS provider.

            For example, if the documentation says the credential must be located in the environment
            variable DNSPROVIDER_TOKEN, then the file content must be:

            DNSPROVIDER_TOKEN=xyz

            You can put non-secret environment variables here too or use shb.ssl.additionalcfg instead.
            '';
            example = "/run/secrets/ssl";
            default = null;
          };

          additionalEnvironment = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            description = ''
              Additional environment variables used to configure the DNS provider.

              For secrets, use shb.ssl.credentialsFile instead.

              See the chosen provider's [documentation](https://go-acme.github.io/lego/dns/) for
              available options.
            '';
            example = lib.literalExpression ''
            {
              DNSPROVIDER_TIMEOUT = "10";
              DNSPROVIDER_PROPAGATION_TIMEOUT = "240";
            }
            '';
          };

          makeAvailableToUser = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = ''
              Make all certificates available to given user.
            '';
            default = null;
          };

          adminEmail = lib.mkOption {
            description = "Admin email in case certificate retrieval goes wrong.";
            type = lib.types.str;
          };

          debug = lib.mkOption {
            description = "Enable debug logging";
            type = lib.types.bool;
            default = false;
          };
        };
      }));
    };
  };

  config =
    let
      filterProvider = provider: lib.attrsets.filterAttrs (k: i: i.provider == provider);

      serviceName = lib.strings.removeSuffix ".service";
    in
      lib.mkMerge [
        # Config for self-signed CA.
        {
          systemd.services = lib.mapAttrs' (_name: caCfg:
            lib.nameValuePair (serviceName caCfg.systemdService) {
              wantedBy = [ "multi-user.target" ];
              wants = [ config.shb.certs.systemdService ];
              before = [ config.shb.certs.systemdService ];
              serviceConfig.Type = "oneshot";
              serviceConfig.RuntimeDirectory = serviceName caCfg.systemdService;
              # serviceConfig.User = "nextcloud";
              # Taken from https://github.com/NixOS/nixpkgs/blob/7f311dd9226bbd568a43632c977f4992cfb2b5c8/nixos/tests/custom-ca.nix
              script = ''
                cd $RUNTIME_DIRECTORY

                cat >ca.template <<EOF
                organization = "${caCfg.name}"
                cn = "${caCfg.name}"
                expiration_days = 365
                ca
                cert_signing_key
                crl_signing_key
                EOF

                mkdir -p "$(dirname -- "${caCfg.paths.key}")"
                ${pkgs.gnutls}/bin/certtool  \
                  --generate-privkey         \
                  --key-type rsa             \
                  --sec-param High           \
                  --outfile ${caCfg.paths.key}
                chmod 666 ${caCfg.paths.key}

                mkdir -p "$(dirname -- "${caCfg.paths.cert}")"
                ${pkgs.gnutls}/bin/certtool         \
                  --generate-self-signed            \
                  --load-privkey ${caCfg.paths.key} \
                  --template ca.template            \
                  --outfile ${caCfg.paths.cert}
                chmod 666 ${caCfg.paths.cert}
              '';
            }
          ) cfg.cas.selfsigned;
        }
        {
          systemd.services.${serviceName config.shb.certs.systemdService} = (lib.mkIf (cfg.cas.selfsigned != {}) {
            wantedBy = [ "multi-user.target" ];
            serviceConfig.Type = "oneshot";
            script = ''
            mkdir -p /etc/ssl/certs

            rm -f /etc/ssl/certs/ca-bundle.crt
            rm -f /etc/ssl/certs/ca-certificates.crt

            cat /etc/static/ssl/certs/ca-bundle.crt > /etc/ssl/certs/ca-bundle.crt
            cat /etc/static/ssl/certs/ca-bundle.crt > /etc/ssl/certs/ca-certificates.crt
            for file in ${lib.concatStringsSep " " (lib.mapAttrsToList (_name: caCfg: caCfg.paths.cert) cfg.cas.selfsigned)}; do
                cat "$file" >> /etc/ssl/certs/ca-bundle.crt
                cat "$file" >> /etc/ssl/certs/ca-certificates.crt
            done
            '';
          });
        }
        # Config for self-signed cert.
        {
          systemd.services = lib.mapAttrs' (_name: certCfg:
            lib.nameValuePair (serviceName certCfg.systemdService) {
              after = [ certCfg.ca.systemdService ];
              requires = [ certCfg.ca.systemdService ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig.RuntimeDirectory = serviceName certCfg.systemdService;
              # Taken from https://github.com/NixOS/nixpkgs/blob/7f311dd9226bbd568a43632c977f4992cfb2b5c8/nixos/tests/custom-ca.nix
              script =
                let
                  extraDnsNames = lib.strings.concatStringsSep "\n" (map (n: "dns_name = ${n}") certCfg.extraDomains);
                in
                ''
                cd $RUNTIME_DIRECTORY

                # server cert template
                cat >server.template <<EOF
                organization = "An example company"
                cn = "${certCfg.domain}"
                expiration_days = 30
                dns_name = "${certCfg.domain}"
                ${extraDnsNames}
                encryption_key
                signing_key
                EOF

                mkdir -p "$(dirname -- "${certCfg.paths.key}")"
                ${pkgs.gnutls}/bin/certtool  \
                  --generate-privkey         \
                  --key-type rsa             \
                  --sec-param High           \
                  --outfile ${certCfg.paths.key}
                chmod 666 ${certCfg.paths.key}

                mkdir -p "$(dirname -- "${certCfg.paths.cert}")"
                ${pkgs.gnutls}/bin/certtool                      \
                  --generate-certificate                         \
                  --load-privkey ${certCfg.paths.key}            \
                  --load-ca-privkey ${certCfg.ca.paths.key}      \
                  --load-ca-certificate ${certCfg.ca.paths.cert} \
                  --template server.template                     \
                  --outfile ${certCfg.paths.cert}
                chmod 666 ${certCfg.paths.cert}
              '';

              serviceConfig.Type = "oneshot";
              # serviceConfig.User = "nextcloud";
            }
          ) cfg.certs.selfsigned;
        }
        # Config for Let's Encrypt cert.
        {
          users.users = lib.mkMerge (lib.mapAttrsToList (name: certCfg: {
            ${certCfg.makeAvailableToUser}.extraGroups = lib.mkIf (!(isNull certCfg.makeAvailableToUser)) [
              config.security.acme.defaults.group
            ];
          }) cfg.certs.letsencrypt);

          security.acme.acceptTerms = lib.mkIf (cfg.certs.letsencrypt != {}) true;

          security.acme.certs = lib.mkMerge (lib.mapAttrsToList (name: certCfg: {
            "${name}" = {
              extraDomainNames = [ certCfg.domain ] ++ certCfg.extraDomains;
              email = certCfg.adminEmail;
              inherit (certCfg) dnsProvider dnsResolver;
              credentialsFile = certCfg.credentialsFile;
              enableDebugLogs = certCfg.debug;
            };
          }) cfg.certs.letsencrypt);

          systemd.services = lib.mkMerge (lib.mapAttrsToList (name: certCfg: {
            "acme-${certCfg.domain}".environment = certCfg.additionalEnvironment;
          }) cfg.certs.letsencrypt);
        }
      ];
}
