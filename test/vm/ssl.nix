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
          mycert = {
            ca = config.shb.certs.cas.selfsigned.myca;

            domain = "example.com";
          };
        };
      };

      # The configuration below is to create a webserver that uses the server certificate.
      networking.hosts."127.0.0.1" = [ "example.com" ];

      services.nginx.enable = true;
      services.nginx.virtualHosts."example.com" =
        {
          onlySSL = true;
          sslCertificate = config.shb.certs.certs.selfsigned.mycert.paths.cert;
          sslCertificateKey = config.shb.certs.certs.selfsigned.mycert.paths.key;
          locations."/".extraConfig = ''
            add_header Content-Type text/plain;
            return 200 'It works!';
          '';
        };
      systemd.services.nginx = {
        after = [ config.shb.certs.certs.selfsigned.mycert.systemdService ];
        requires = [ config.shb.certs.certs.selfsigned.mycert.systemdService ];
      };
    };

    # Taken from https://github.com/NixOS/nixpkgs/blob/7f311dd9226bbd568a43632c977f4992cfb2b5c8/nixos/tests/custom-ca.nix
    testScript = { nodes, ... }:
      let
        myca = nodes.server.shb.certs.cas.selfsigned.myca;
        myotherca = nodes.server.shb.certs.cas.selfsigned.myotherca;
        mycert = nodes.server.shb.certs.certs.selfsigned.mycert;
      in
        ''
        start_all()

        # Make sure certs are generated.
        server.wait_for_file("${myca.paths.key}")
        server.wait_for_file("${myca.paths.cert}")
        server.wait_for_file("${myotherca.paths.key}")
        server.wait_for_file("${myotherca.paths.cert}")
        server.wait_for_file("${mycert.paths.key}")
        server.wait_for_file("${mycert.paths.cert}")

        # Wait for jkkk
        server.require_unit_state("${nodes.server.shb.certs.systemdService}", "inactive")

        with subtest("Certificate is trusted in curl"):
            machine.wait_for_unit("nginx")
            machine.wait_for_open_port(443)
            machine.succeed("curl --fail-with-body -v https://example.com")
        '';
  };
}
