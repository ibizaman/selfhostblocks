{ pkgs, lib, ... }:
{
  test = pkgs.nixosTest {
    name = "ssl-test";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        ../../modules/blocks/ssl.nix
      ];

      shb.certs = {
        cas.selfsigned = {
          myca = {
            name = "My CA";
          };
          myotherca = {
            name = "My Other CA";
          };
        };
        certs.selfsigned = {
          top = {
            ca = config.shb.certs.cas.selfsigned.myca;

            domain = "example.com";
          };
          subdomain = {
            ca = config.shb.certs.cas.selfsigned.myca;

            domain = "subdomain.example.com";
          };
          multi = {
            ca = config.shb.certs.cas.selfsigned.myca;

            domain = "multi1.example.com";
            extraDomains = [ "multi2.example.com" "multi3.example.com" ];
          };
        };
      };

      # The configuration below is to create a webserver that uses the server certificate.
      networking.hosts."127.0.0.1" = [
        "example.com"
        "subdomain.example.com"
        "wrong.example.com"
        "multi1.example.com"
        "multi2.example.com"
        "multi3.example.com"
      ];

      services.nginx.enable = true;
      services.nginx.virtualHosts =
        let
          mkVirtualHost = response: cert: {
            onlySSL = true;
            sslCertificate = cert.paths.cert;
            sslCertificateKey = cert.paths.key;
            locations."/".extraConfig = ''
              add_header Content-Type text/plain;
              return 200 '${response}';
            '';
          };
        in
          {
            "example.com" = mkVirtualHost "Top domain" config.shb.certs.certs.selfsigned.top;
            "subdomain.example.com" = mkVirtualHost "Subdomain" config.shb.certs.certs.selfsigned.subdomain;
            "multi1.example.com" = mkVirtualHost "multi1" config.shb.certs.certs.selfsigned.multi;
            "multi2.example.com" = mkVirtualHost "multi2" config.shb.certs.certs.selfsigned.multi;
            "multi3.example.com" = mkVirtualHost "multi3" config.shb.certs.certs.selfsigned.multi;
          };
      systemd.services.nginx = {
        after = [ config.shb.certs.certs.selfsigned.top.systemdService config.shb.certs.certs.selfsigned.subdomain.systemdService ];
        requires = [ config.shb.certs.certs.selfsigned.top.systemdService config.shb.certs.certs.selfsigned.subdomain.systemdService ];
      };
    };

    # Taken from https://github.com/NixOS/nixpkgs/blob/7f311dd9226bbd568a43632c977f4992cfb2b5c8/nixos/tests/custom-ca.nix
    testScript = { nodes, ... }:
      let
        myca = nodes.server.shb.certs.cas.selfsigned.myca;
        myotherca = nodes.server.shb.certs.cas.selfsigned.myotherca;
        top = nodes.server.shb.certs.certs.selfsigned.top;
        subdomain = nodes.server.shb.certs.certs.selfsigned.subdomain;
        multi = nodes.server.shb.certs.certs.selfsigned.multi;
      in
        ''
        start_all()

        # Make sure certs are generated.
        server.wait_for_file("${myca.paths.key}")
        server.wait_for_file("${myca.paths.cert}")
        server.wait_for_file("${myotherca.paths.key}")
        server.wait_for_file("${myotherca.paths.cert}")
        server.wait_for_file("${top.paths.key}")
        server.wait_for_file("${top.paths.cert}")
        server.wait_for_file("${subdomain.paths.key}")
        server.wait_for_file("${subdomain.paths.cert}")
        server.wait_for_file("${multi.paths.key}")
        server.wait_for_file("${multi.paths.cert}")

        server.require_unit_state("${nodes.server.shb.certs.systemdService}", "inactive")

        server.wait_for_unit("nginx")
        server.wait_for_open_port(443)

        with subtest("Certificate is trusted in curl"):
            resp = server.succeed("curl --fail-with-body -v https://example.com")
            if resp != "Top domain":
                raise Exception('Unexpected response, got: {}'.format(resp))

            resp = server.succeed("curl --fail-with-body -v https://subdomain.example.com")
            if resp != "Subdomain":
                raise Exception('Unexpected response, got: {}'.format(resp))

            resp = server.succeed("curl --fail-with-body -v https://multi1.example.com")
            if resp != "multi1":
                raise Exception('Unexpected response, got: {}'.format(resp))

            resp = server.succeed("curl --fail-with-body -v https://multi2.example.com")
            if resp != "multi2":
                raise Exception('Unexpected response, got: {}'.format(resp))

            resp = server.succeed("curl --fail-with-body -v https://multi3.example.com")
            if resp != "multi3":
                raise Exception('Unexpected response, got: {}'.format(resp))

        with subtest("Fail if certificate is not in CA bundle"):
            server.fail("curl --cacert /etc/static/ssl/certs/ca-bundle.crt --fail-with-body -v https://example.com")
            server.fail("curl --cacert /etc/static/ssl/certs/ca-bundle.crt --fail-with-body -v https://subdomain.example.com")
            server.fail("curl --cacert /etc/static/ssl/certs/ca-certificates.crt --fail-with-body -v https://example.com")
            server.fail("curl --cacert /etc/static/ssl/certs/ca-certificates.crt --fail-with-body -v https://subdomain.example.com")
        '';
  };
}
