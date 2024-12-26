{ config, pkgs, lib, ... }:

let
  cfg = config.shb.certs;

  contracts = pkgs.callPackage ../contracts {};

  inherit (builtins) dirOf;
  inherit (lib) flatten mapAttrsToList unique;
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

              This option implements the SSL Generator contract.
            '';
            type = contracts.ssl.certs-paths;
            default = rec {
              key = "/var/lib/certs/cas/${config._module.args.name}.key";
              cert = "/var/lib/certs/cas/${config._module.args.name}.cert";
            };
          };

          systemdService = lib.mkOption {
            description = ''
              Systemd oneshot service used to generate the certs.

              This option implements the SSL Generator contract.
            '';
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

          group = lib.mkOption {
            type = lib.types.str;
            description = ''
              Unix group owning this certificate.
            '';
            default = "root";
            example = "nginx";
          };

          paths = lib.mkOption {
            description = ''
              Paths where certs will be located.

              This option implements the SSL Generator contract.
            '';
            type = contracts.ssl.certs-paths;
            default = rec {
              key = "/var/lib/certs/selfsigned/${config._module.args.name}.key";
              cert = "/var/lib/certs/selfsigned/${config._module.args.name}.cert";
            };
          };

          systemdService = lib.mkOption {
            description = ''
              Systemd oneshot service used to generate the certs.

              This option implements the SSL Generator contract.
            '';
            type = lib.types.str;
            default = "shb-certs-cert-selfsigned-${config._module.args.name}.service";
          };

          reloadServices = lib.mkOption {
            description = ''
              The list of systemd services to call `systemctl try-reload-or-restart` on.
            '';
            type = lib.types.listOf lib.types.str;
            default = [];
            example = [ "nginx.service" ];
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

              This option implements the SSL Generator contract.
            '';
            type = contracts.ssl.certs-paths;
            default = {
              key = "/var/lib/acme/${config._module.args.name}/key.pem";
              cert = "/var/lib/acme/${config._module.args.name}/cert.pem";
            };
          };

          group = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = ''
              Unix group owning this certificate.
            '';
            default = "acme";
            example = "nginx";
          };

          systemdService = lib.mkOption {
            description = ''
              Systemd oneshot service used to generate the certs.

              This option implements the SSL Generator contract.
            '';
            type = lib.types.str;
            default = "shb-certs-cert-letsencrypt-${config._module.args.name}.service";
          };

          afterAndWants = lib.mkOption {
            description = ''
              Systemd service(s) that must start successfully before attempting to reach acme.
            '';
            type = lib.types.listOf lib.types.str;
            default = [];
            example = lib.literalExpression ''
            [ "dnsmasq.service" ]
            '';
          };

          reloadServices = lib.mkOption {
            description = ''
              The list of systemd services to call `systemctl try-reload-or-restart` on.
            '';
            type = lib.types.listOf lib.types.str;
            default = [];
            example = [ "nginx.service" ];
          };

          dnsProvider = lib.mkOption {
            description = ''
              DNS provider to use.

              See https://go-acme.github.io/lego/dns/ for the list of supported providers.

              If null is given, use instead the reverse proxy to validate the domain.
            '';
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
            default = {};
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

          stagingServer = lib.mkOption {
            description = "User Let's Encrypt's staging server.";
            type = lib.types.bool;
            default = false;
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
        # Config for self-signed CA bundle.
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
            for file in ${lib.concatStringsSep " " (mapAttrsToList (_name: caCfg: caCfg.paths.cert) cfg.cas.selfsigned)}; do
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
                  chmod = cert:
                    ''
                      chown root:${certCfg.group} ${cert}
                      chmod 640 ${cert}
                    '';
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
                ${chmod certCfg.paths.key}

                mkdir -p "$(dirname -- "${certCfg.paths.cert}")"
                ${pkgs.gnutls}/bin/certtool                      \
                  --generate-certificate                         \
                  --load-privkey ${certCfg.paths.key}            \
                  --load-ca-privkey ${certCfg.ca.paths.key}      \
                  --load-ca-certificate ${certCfg.ca.paths.cert} \
                  --template server.template                     \
                  --outfile ${certCfg.paths.cert}
                ${chmod certCfg.paths.cert}
              '';

              postStart = lib.optionalString (certCfg.reloadServices != []) ''
                systemctl --no-block try-reload-or-restart ${lib.escapeShellArgs certCfg.reloadServices}
              '';

              serviceConfig.Type = "oneshot";
              # serviceConfig.User = "nextcloud";
            }
          ) cfg.certs.selfsigned;
        }
        # Config for Let's Encrypt cert.
        {
          users.users = lib.mkMerge (mapAttrsToList (name: certCfg: {
            ${certCfg.makeAvailableToUser}.extraGroups = lib.mkIf (!(isNull certCfg.makeAvailableToUser)) [
              config.security.acme.defaults.group
            ];
          }) cfg.certs.letsencrypt);

          security.acme.acceptTerms = lib.mkIf (cfg.certs.letsencrypt != {}) true;

          security.acme.certs = let
            extraDomainsCfg = certCfg: map (name: {
              "${name}" = {
                email = certCfg.adminEmail;
                enableDebugLogs = certCfg.debug;
                server = lib.mkIf certCfg.stagingServer "https://acme-staging-v02.api.letsencrypt.org/directory";
              };
            }) certCfg.extraDomains;
          in lib.mkMerge (flatten (mapAttrsToList (name: certCfg:
            [{
              "${name}" = {
                extraDomainNames = [ certCfg.domain ] ++ certCfg.extraDomains;
                email = certCfg.adminEmail;
                enableDebugLogs = certCfg.debug;
                server = lib.mkIf certCfg.stagingServer "https://acme-staging-v02.api.letsencrypt.org/directory";
              } // lib.optionalAttrs (certCfg.dnsProvider != null) {
                inherit (certCfg) dnsProvider dnsResolver;
                inherit (certCfg) group reloadServices;
                credentialsFile = certCfg.credentialsFile;
              };
            }]
            ++ lib.optionals (certCfg.dnsProvider == null) (extraDomainsCfg certCfg)
          ) cfg.certs.letsencrypt));

          services.nginx = let
            extraDomainsCfg = extraDomains: map (name: {
              virtualHosts."${name}" = {
                # addSSL = true;
                enableACME = true;
              };
            }) extraDomains;
          in lib.mkMerge (flatten (mapAttrsToList (name: certCfg:
            lib.optionals (certCfg.dnsProvider == null) (
              [{
                virtualHosts."${name}" = {
                  # addSSL = true;
                  enableACME = true;
                };
              }]
              ++ extraDomainsCfg certCfg.extraDomains
            )) cfg.certs.letsencrypt));

          systemd.services = let
            extraDomainsCfg = certCfg: flatten (map (name:
              lib.optionals (certCfg.additionalEnvironment != {} && certCfg.dnsProvider == null) [{
                "acme-${name}".environment = certCfg.additionalEnvironment;
              }]
              ++ lib.optionals (certCfg.afterAndWants != [] && certCfg.dnsProvider == null) [{
                "acme-${name}" = {
                  after = certCfg.afterAndWants;
                  wants = certCfg.afterAndWants;
                };
              }]
            ) certCfg.extraDomains);
          in lib.mkMerge (flatten (mapAttrsToList (name: certCfg:
            lib.optionals (certCfg.additionalEnvironment != {} && certCfg.dnsProvider == null) [{
              "acme-${certCfg.domain}".environment = certCfg.additionalEnvironment;
            }]
            ++ lib.optionals (certCfg.afterAndWants != [] && certCfg.dnsProvider == null) [{
              "acme-${certCfg.domain}" = {
                after = certCfg.afterAndWants;
                wants = certCfg.afterAndWants;
              };
            }]
            ++ lib.optionals (certCfg.dnsProvider == null) (extraDomainsCfg certCfg)
          ) cfg.certs.letsencrypt));

          services.prometheus.exporters.node-cert = {
            enable = true;
            listenAddress = "127.0.0.1";
            user = "acme";
            paths = let
              pathCfg = name: certCfg:
                let
                  mainDomainPaths = map dirOf [ certCfg.paths.cert certCfg.paths.key ];
                  # Not sure this will work for all cases.
                  mainPath = dirOf (dirOf certCfg.paths.cert);
                  extraDomainsPath = map (x: "${mainPath}/${x}") certCfg.extraDomains;
                in
                  mainDomainPaths ++ extraDomainsPath;
            in
              unique (flatten (mapAttrsToList pathCfg cfg.certs.letsencrypt));
          };

          services.prometheus.scrapeConfigs = let
            scrapeCfg = name: certCfg: [{
              job_name = "node-cert-${name}";
              static_configs = [{
                targets = ["127.0.0.1:${toString config.services.prometheus.exporters.node-cert.port}"];
                labels = {
                  "hostname" = config.networking.hostName;
                  "domain" = certCfg.domain;
                };
              }];
            }];
          in
            flatten (mapAttrsToList scrapeCfg cfg.certs.letsencrypt);
        }
      ];
}
