{
  config,
  pkgs,
  lib,
  shb,
  ...
}:

let
  cfg = config.shb.certs;

  inherit (builtins) dirOf;
  inherit (lib)
    flatten
    mapAttrsToList
    optionalAttrs
    optionals
    unique
    ;

  caType = lib.types.submodule (
    { config, ... }:
    {
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
          type = lib.types.submodule {
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
          default = {
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
    }
  );
in
{
  imports = [
    ../../lib/module.nix
    ./monitoring.nix
  ];

  options.shb.certs = {
    systemdService = lib.mkOption {
      description = ''
        Systemd oneshot service used to generate the Certificate Authority bundle.
      '';
      type = lib.types.str;
      default = "shb-ca-bundle.service";
    };
    enableDashboard = lib.mkEnableOption "the SSL SHB dashboard" // {
      default = true;
    };
    cas.selfsigned = lib.mkOption {
      description = "Generate a self-signed Certificate Authority.";
      default = { };
      type = lib.types.attrsOf caType;
    };
    certs.selfsigned = lib.mkOption {
      description = "Generate self-signed certificates signed by a Certificate Authority.";
      default = { };
      type = lib.types.attrsOf (
        shb.contracts.ssl.mkProvider (
          { config, name, ... }:
          {
            options = {
              settings = lib.mkOption {
                type = lib.types.submodule {
                  options.ca = lib.mkOption {
                    type = lib.types.nullOr caType;
                    description = ''
                      CA used to generate this certificate. Only used for self-signed.

                      This contract input takes the contract output of the `shb.certs.cas` SSL block.
                    '';
                    default = null;
                  };
                };
              };
              result = {
                cert = lib.mkOption { default = "/var/lib/certs/cas/${config._module.args.name}.cert"; };
                key = lib.mkOption { default = "/var/lib/certs/cas/${config._module.args.name}.key"; };
                systemdService = lib.mkOption {
                  default = "shb-certs-cert-selfsigned-${name}.service";
                };
              };
            };
          }
        )
      );
    };

    certs.letsencrypt = lib.mkOption {
      description = "Generate certificates signed by [Let's Encrypt](https://letsencrypt.org/).";
      default = { };
      type = lib.types.attrsOf (
        shb.contracts.ssl.mkProvider (
          { config, ... }:
          {
            options = {
              settings = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    afterAndWants = lib.mkOption {
                      description = ''
                        Systemd service(s) that must start successfully before attempting to reach acme.
                      '';
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                      example = lib.literalExpression ''
                        [ "dnsmasq.service" ]
                      '';
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
                      default = { };
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
                };
              };
              result = {
                key = lib.mkOption { default = "/var/lib/acme/${config._module.args.name}/key.pem"; };
                cert = lib.mkOption { default = "/var/lib/acme/${config._module.args.name}/cert.pem"; };
                systemdService = lib.mkOption {
                  default = "acme-${config._module.args.name}.service";
                };
              };
            };
          }
        )
      );
    };
  };

  config =
    let
      serviceName = lib.strings.removeSuffix ".service";
    in
    lib.mkMerge [
      # Generic assertions
      {
        assertions = lib.flatten (
          lib.mapAttrsToList (
            _name: certCfg:
            (
              let
                domainInExtraDomains =
                  (lib.lists.findFirstIndex (x: x == certCfg.request.domain) null certCfg.request.extraDomains)
                  != null;
                firstDuplicateDomain =
                  (
                    l:
                    let
                      sorted = lib.sort (x: y: x < y) l;
                      maybeDupe = lib.lists.removePrefix (lib.lists.commonPrefix (lib.uniqueStrings sorted) sorted) sorted;
                    in
                    if maybeDupe == [ ] then null else lib.head maybeDupe
                  )
                    certCfg.request.extraDomains;
              in
              [
                {
                  assertion = !domainInExtraDomains;
                  message = "Error in SHB option for domain ${certCfg.domain}: do not repeat the domain name in the `extraDomain` option.";
                }
                {
                  assertion = firstDuplicateDomain == null;
                  message = "Error in SHB option for domain ${certCfg.domain}: `extraDomain` option cannot have duplicates, first offender is: ${firstDuplicateDomain} in the following list: ${lib.concatStringsSep " " certCfg.extraDomains}.";
                }
              ]
            )
          ) (cfg.certs.selfsigned // cfg.certs.letsencrypt)
        );
      }
      # Config for self-signed CA.
      {
        systemd.services = lib.mapAttrs' (
          _name: caCfg:
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

              keyfile="${caCfg.paths.key}"
              keydir="$(dirname -- "$keyfile")"
              mkdir -p "$keydir"
              [ -f "$keyfile" ] || ${pkgs.gnutls}/bin/certtool \
                --generate-privkey \
                --key-type rsa \
                --sec-param High \
                --outfile "$keyfile"
              chmod 666 "$keyfile"

              certfile="${caCfg.paths.cert}"
              certdir="$(dirname -- "$certfile")"
              mkdir -p "$certdir"
              [ -f "$certfile" ] || ${pkgs.gnutls}/bin/certtool \
                --generate-self-signed \
                --load-privkey "$keyfile" \
                --template ca.template \
                --outfile "$certfile"
              chmod 666 "$certfile"
            '';
          }
        ) cfg.cas.selfsigned;
      }
      # Config for self-signed CA bundle.
      {
        systemd.services.${serviceName config.shb.certs.systemdService} = (
          lib.mkIf (cfg.cas.selfsigned != { }) {
            wantedBy = [ "multi-user.target" ];
            serviceConfig.Type = "oneshot";
            script = ''
              mkdir -p /etc/ssl/certs

              # This file is automatically idempotent since the source files used are idempotent.

              rm -f /etc/ssl/certs/ca-bundle.crt
              rm -f /etc/ssl/certs/ca-certificates.crt

              cat /etc/static/ssl/certs/ca-bundle.crt > /etc/ssl/certs/ca-bundle.crt
              cat /etc/static/ssl/certs/ca-bundle.crt > /etc/ssl/certs/ca-certificates.crt
              for file in ${
                lib.concatStringsSep " " (mapAttrsToList (_name: caCfg: caCfg.paths.cert) cfg.cas.selfsigned)
              }; do
                  cat "$file" >> /etc/ssl/certs/ca-bundle.crt
                  cat "$file" >> /etc/ssl/certs/ca-certificates.crt
              done
            '';
          }
        );
      }
      # Config for self-signed cert.
      {
        shb.contractResults = shb.contracts.ssl.register (lib.attrValues cfg.certs.selfsigned);
        systemd.services = lib.mapAttrs' (
          _name: certCfg:
          lib.nameValuePair (serviceName certCfg.result.systemdService) {
            after = [ certCfg.settings.ca.systemdService ];
            requires = [ certCfg.settings.ca.systemdService ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig.RuntimeDirectory = serviceName certCfg.result.systemdService;
            # Taken from https://github.com/NixOS/nixpkgs/blob/7f311dd9226bbd568a43632c977f4992cfb2b5c8/nixos/tests/custom-ca.nix
            script =
              let
                extraDnsNames = lib.strings.concatStringsSep "\n" (
                  map (n: "dns_name = ${n}") certCfg.request.extraDomains
                );
                chmod = cert: ''
                  chown root:${certCfg.request.group} "${cert}"
                  chmod 640 "${cert}"
                '';
              in
              ''
                cd $RUNTIME_DIRECTORY

                # server cert template
                cat >server.template <<EOF
                organization = "An example company"
                cn = "${certCfg.request.domain}"
                expiration_days = 30
                dns_name = "${certCfg.request.domain}"
                ${extraDnsNames}
                encryption_key
                signing_key
                EOF

                keyfile="${certCfg.result.key}"
                keydir="$(dirname -- "$keyfile")"
                mkdir -p "$keydir"
                [ -f "$keyfile" ] || ${pkgs.gnutls}/bin/certtool \
                  --generate-privkey \
                  --key-type rsa \
                  --sec-param High \
                  --outfile "$keyfile"
                ${chmod "$keyfile"}

                certfile="${certCfg.result.cert}"
                certdir="$(dirname -- "$certfile")"
                mkdir -p "$certdir"
                [ -f "$certfile" ] || ${pkgs.gnutls}/bin/certtool \
                  --generate-certificate \
                  --load-privkey "$keyfile" \
                  --load-ca-privkey "${certCfg.settings.ca.paths.key}" \
                  --load-ca-certificate "${certCfg.settings.ca.paths.cert}" \
                  --template server.template \
                  --outfile "$certfile"
                ${chmod "$certfile"}
              '';

            postStart = lib.optionalString (certCfg.result.reloadServices != [ ]) ''
              systemctl --no-block try-reload-or-restart ${lib.escapeShellArgs certCfg.result.reloadServices}
            '';

            serviceConfig.Type = "oneshot";
            # serviceConfig.User = "nextcloud";
          }
        ) cfg.certs.selfsigned;
      }
      # Config for Let's Encrypt cert.
      {

        shb.contractResults = shb.contracts.ssl.register (lib.attrValues cfg.certs.letsencrypt);
        users.users = lib.mkMerge (
          mapAttrsToList (name: certCfg: {
            ${certCfg.settings.makeAvailableToUser}.extraGroups =
              lib.mkIf (!(isNull certCfg.makeAvailableToUser))
                [
                  config.security.acme.defaults.group
                ];
          }) cfg.certs.letsencrypt
        );

        security.acme.acceptTerms = lib.mkIf (cfg.certs.letsencrypt != { }) true;

        security.acme.certs =
          let
            extraDomainsCfg =
              certCfg:
              map (name: {
                "${name}" = {
                  email = certCfg.adminEmail;
                  enableDebugLogs = certCfg.debug;
                  server = lib.mkIf certCfg.stagingServer "https://acme-staging-v02.api.letsencrypt.org/directory";
                };
              }) certCfg.request.extraDomains;
          in
          lib.mkMerge (
            flatten (
              mapAttrsToList (
                name: certCfg:
                [
                  {
                    "${name}" = {
                      inherit (certCfg.request) domain group;
                      extraDomainNames = certCfg.request.extraDomains;
                      email = certCfg.settings.adminEmail;
                      enableDebugLogs = certCfg.settings.debug;
                      server = lib.mkIf certCfg.settings.stagingServer "https://acme-staging-v02.api.letsencrypt.org/directory";
                    }
                    // lib.optionalAttrs (certCfg.settings.dnsProvider != null) {
                      inherit (certCfg.settings) dnsProvider dnsResolver;
                      inherit (certCfg.result) reloadServices;
                      environmentFile = certCfg.settings.credentialsFile;
                    };
                  }
                ]
                ++ lib.optionals (certCfg.settings.dnsProvider == null) (extraDomainsCfg certCfg)
              ) cfg.certs.letsencrypt
            )
          );

        services.nginx =
          let
            extraDomainsCfg =
              extraDomains:
              map (name: {
                virtualHosts."${name}" = {
                  # addSSL = true;
                  enableACME = true;
                };
              }) extraDomains;
          in
          lib.mkMerge (
            flatten (
              mapAttrsToList (
                name: certCfg:
                lib.optionals (certCfg.settings.dnsProvider == null) (
                  [
                    {
                      virtualHosts."${name}" = {
                        # addSSL = true;
                        enableACME = true;
                      };
                    }
                  ]
                  ++ extraDomainsCfg certCfg.extraDomains
                )
              ) cfg.certs.letsencrypt
            )
          );

        systemd.services =
          let
            extraDomainsCfg =
              certCfg:
              flatten (
                map (
                  name:
                  lib.optionals
                    (certCfg.settings.additionalEnvironment != { } && certCfg.settings.dnsProvider == null)
                    [
                      {
                        "acme-${name}".environment = certCfg.settings.additionalEnvironment;
                      }
                    ]
                  ++ lib.optionals (certCfg.settings.afterAndWants != [ ] && certCfg.settings.dnsProvider == null) [
                    {
                      "acme-${name}" = {
                        after = certCfg.settings.afterAndWants;
                        wants = certCfg.settings.afterAndWants;
                      };
                    }
                  ]
                ) certCfg.extraDomains
              );
          in
          lib.mkMerge (
            flatten (
              mapAttrsToList (
                name: certCfg:
                lib.optionals
                  (certCfg.settings.additionalEnvironment != { } && certCfg.settings.dnsProvider == null)
                  [
                    {
                      "acme-${certCfg.domain}".environment = certCfg.settings.additionalEnvironment;
                    }
                  ]
                ++ lib.optionals (certCfg.settings.afterAndWants != [ ] && certCfg.settings.dnsProvider == null) [
                  {
                    "acme-${certCfg.domain}" = {
                      after = certCfg.settings.afterAndWants;
                      wants = certCfg.settings.afterAndWants;
                    };
                  }
                ]
                ++ lib.optionals (certCfg.settings.dnsProvider == null) (extraDomainsCfg certCfg)
              ) cfg.certs.letsencrypt
            )
          );

        services.prometheus.exporters.node-cert = optionalAttrs (cfg.certs.letsencrypt != { }) {
          enable = true;
          listenAddress = "127.0.0.1";
          user = "acme";
          paths =
            let
              pathCfg =
                name: certCfg:
                let
                  mainDomainPaths = map dirOf [
                    certCfg.result.cert
                    certCfg.result.key
                  ];
                  # Not sure this will work for all cases.
                  mainPath = dirOf (dirOf certCfg.result.cert);
                  extraDomainsPath = map (x: "${mainPath}/${x}") certCfg.request.extraDomains;
                in
                mainDomainPaths ++ extraDomainsPath;
            in
            unique (flatten (mapAttrsToList pathCfg cfg.certs.letsencrypt));
        };

        services.prometheus.scrapeConfigs =
          let
            scrapeCfg = name: certCfg: [
              {
                job_name = "node-cert-${name}";
                static_configs = [
                  {
                    targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node-cert.port}" ];
                    labels = {
                      "hostname" = config.networking.hostName;
                      "domain" = certCfg.domain;
                    };
                  }
                ];
              }
            ];
          in
          optionals (cfg.certs.letsencrypt != { }) (flatten (mapAttrsToList scrapeCfg cfg.certs.letsencrypt));
      }
      (lib.mkIf (cfg.enableDashboard && (cfg.certs.selfsigned != { } || cfg.certs.letsencrypt != { })) {
        shb.monitoring.dashboards = [
          ./ssl/dashboard/SSL.json
        ];
      })
    ];
}
