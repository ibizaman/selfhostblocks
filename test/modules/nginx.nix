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
              shb.ssl = anyOpt {};
            };
          }
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
      shb.backup = {};
      shb.nginx = {
        accessLog = false;
        autheliaProtect = [{
          authEndpoint = "hello";
          autheliaRules = [{}];
          subdomain = "my";
          domain = "example.com";
          upstream = "http://127.0.0.1:1234";
        }];
        debugLog = false;
      };
      services.nginx.enable = true;
      services.nginx.virtualHosts."my.example.com" = {
        forceSSL = true;
        locations."/" = {};
        locations."/authelia" = {};
        sslCertificate = "/var/lib/acme/example.com/cert.pem";
        sslCertificateKey = "/var/lib/acme/example.com/key.pem";
      };
    };
    expr = testConfig {
      shb.ssl.enable = true;
      shb.nginx.autheliaProtect = [{
        subdomain = "my";
        domain = "example.com";
        upstream = "http://127.0.0.1:1234";
        authEndpoint = "hello";
        autheliaRules = [{}];
      }];
    };
  };
}
