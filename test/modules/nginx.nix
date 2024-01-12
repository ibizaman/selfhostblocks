{ pkgs, lib, ... }:
let
  anyOpt = default: lib.mkOption {
    type = lib.types.anything;
    inherit default;
  };

  testConfig = m:
    let
      cfg = (lib.evalModules {
        specialArgs = { inherit pkgs; };
        modules = [
          {
            options = {
              assertions = anyOpt [];
              networking = anyOpt {};
              security = anyOpt {};
              services = anyOpt {};
              shb.authelia = anyOpt {};
              shb.backup = anyOpt {};
              systemd = anyOpt {};
              users = anyOpt {};
            };
          }
          ../../modules/blocks/ssl.nix
          ../../modules/blocks/nginx.nix
          m
        ];
      }).config;
    in lib.attrsets.filterAttrsRecursive (n: v: n != "extraConfig") {
      inherit (cfg) services;
      shb = { inherit (cfg.shb) backup nginx; };
    };
in
{
  testNoOptions = {
    expected = {
      shb.backup = {};
      shb.nginx = {
        accessLog = false;
        autheliaProtect = [];
        debugLog = false;
      };
      services.nginx.enable = true;
    };
    expr = testConfig {};
  };

  testAuth = {
    expected = {
      nginx.enable = true;
      nginx.virtualHosts."my.example.com" = {
        forceSSL = true;
        locations."/" = {};
        locations."/authelia" = {};
        sslCertificate = "/var/lib/certs/selfsigned/example.com.cert";
        sslCertificateKey = "/var/lib/certs/selfsigned/example.com.key";
      };
    };
    expr = (testConfig ({ config, ... }: {
      shb.certs.cas.selfsigned.myca = {};

      shb.certs.certs.selfsigned."example.com" = {
        ca = config.shb.certs.cas.selfsigned.myca;

        domain = "example.com";
      };

      shb.nginx.autheliaProtect = [{
        subdomain = "my";
        domain = "example.com";
        ssl = config.shb.certs.certs.selfsigned."example.com";
        upstream = "http://127.0.0.1:1234";
        authEndpoint = "hello";
        autheliaRules = [{}];
      }];
    })).services;
  };
}
