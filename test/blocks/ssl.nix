{ pkgs, shb, ... }:
let
  pkgs' = pkgs;
in
{
  test = shb.test.runNixOSTest {
    name = "ssl-test";

    nodes.server =
      { config, pkgs, ... }:
      {
        imports = [
          (pkgs'.path + "/nixos/modules/profiles/headless.nix")
          (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
          ../../modules/blocks/ssl.nix
        ];

        users.users = {
          user1 = {
            group = "group1";
            isSystemUser = true;
          };
          user2 = {
            group = "group2";
            isSystemUser = true;
          };
        };
        users.groups = {
          group1 = { };
          group2 = { };
        };

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
              group = "nginx";
            };
            subdomain = {
              ca = config.shb.certs.cas.selfsigned.myca;

              domain = "subdomain.example.com";
              group = "nginx";
            };
            multi = {
              ca = config.shb.certs.cas.selfsigned.myca;

              domain = "multi1.example.com";
              extraDomains = [
                "multi2.example.com"
                "multi3.example.com"
              ];
              group = "nginx";
            };

            cert1 = {
              ca = config.shb.certs.cas.selfsigned.myca;

              domain = "cert1.example.com";
            };
            cert2 = {
              ca = config.shb.certs.cas.selfsigned.myca;

              domain = "cert2.example.com";
              group = "group2";
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
          after = [
            config.shb.certs.certs.selfsigned.top.systemdService
            config.shb.certs.certs.selfsigned.subdomain.systemdService
            config.shb.certs.certs.selfsigned.multi.systemdService
            config.shb.certs.certs.selfsigned.cert1.systemdService
            config.shb.certs.certs.selfsigned.cert2.systemdService
          ];
          requires = [
            config.shb.certs.certs.selfsigned.top.systemdService
            config.shb.certs.certs.selfsigned.subdomain.systemdService
            config.shb.certs.certs.selfsigned.multi.systemdService
            config.shb.certs.certs.selfsigned.cert1.systemdService
            config.shb.certs.certs.selfsigned.cert2.systemdService
          ];
        };
      };

    # Taken from https://github.com/NixOS/nixpkgs/blob/7f311dd9226bbd568a43632c977f4992cfb2b5c8/nixos/tests/custom-ca.nix
    testScript =
      { nodes, ... }:
      let
        myca = nodes.server.shb.certs.cas.selfsigned.myca;
        myotherca = nodes.server.shb.certs.cas.selfsigned.myotherca;
        top = nodes.server.shb.certs.certs.selfsigned.top;
        subdomain = nodes.server.shb.certs.certs.selfsigned.subdomain;
        multi = nodes.server.shb.certs.certs.selfsigned.multi;
        cert1 = nodes.server.shb.certs.certs.selfsigned.cert1;
        cert2 = nodes.server.shb.certs.certs.selfsigned.cert2;
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
        server.wait_for_file("${cert1.paths.key}")
        server.wait_for_file("${cert1.paths.cert}")
        server.wait_for_file("${cert2.paths.key}")
        server.wait_for_file("${cert2.paths.cert}")

        server.require_unit_state("${nodes.server.shb.certs.systemdService}", "inactive")

        server.wait_for_unit("nginx")
        server.wait_for_open_port(443)

        def assert_owner(path, user, group):
            owner = server.succeed("stat --format '%U:%G' {}".format(path)).strip();
            want_owner = user + ":" + group
            if owner != want_owner:
                raise Exception('Unexpected owner for {}: wanted "{}", got: "{}"'.format(path, want_owner, owner))

        def assert_perm(path, want_perm):
            perm = server.succeed("stat --format '%a' {}".format(path)).strip();
            if perm != want_perm:
                raise Exception('Unexpected perm for {}: wanted "{}", got: "{}"'.format(path, want_perm, perm))

        with subtest("Certificates content seem correct"):
            myca_key = server.succeed("cat {}".format("${myca.paths.key}")).strip();
            myca_cert = server.succeed("cat {}".format("${myca.paths.cert}")).strip();
            cert1_key = server.succeed("cat {}".format("${cert1.paths.key}")).strip();
            cert1_cert = server.succeed("cat {}".format("${cert1.paths.cert}")).strip();
            cert2_key = server.succeed("cat {}".format("${cert2.paths.key}")).strip();
            cert2_cert = server.succeed("cat {}".format("${cert2.paths.cert}")).strip();
            ca_bundle = server.succeed("cat /etc/ssl/certs/ca-bundle.crt").strip();

            if myca_cert == "":
              raise Exception("CA cert was empty")
            if cert1_key == "":
              raise Exception("Cert1 key was empty")
            if cert1_cert == "":
              raise Exception("Cert1 cert was empty")
            if cert2_key == "":
              raise Exception("Cert2 key was empty")
            if cert2_cert == "":
              raise Exception("Cert2 cert was empty")
            if cert1_key == cert2_key:
              raise Exception("Cert1 key and cert2 key are the same")
            if cert1_cert == cert2_cert:
              raise Exception("Cert1 cert and cert2 cert are the same")
            if ca_bundle == "":
              raise Exception("CA bundle was empty")

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

        with subtest("Certificate has correct permission"):
            assert_owner("${cert1.paths.key}", "root", "root")
            assert_owner("${cert1.paths.cert}", "root", "root")
            assert_perm("${cert1.paths.key}", "640")
            assert_perm("${cert1.paths.cert}", "640")
            
            assert_owner("${cert2.paths.key}", "root", "group2")
            assert_owner("${cert2.paths.cert}", "root", "group2")
            assert_perm("${cert2.paths.key}", "640")
            assert_perm("${cert2.paths.cert}", "640")

        with subtest("Certificates content seem correct"):
            if cert1_key == "":
              raise Exception("Cert1 key was empty")
            if cert1_cert == "":
              raise Exception("Cert1 cert was empty")
            if cert2_key == "":
              raise Exception("Cert2 key was empty")
            if cert2_cert == "":
              raise Exception("Cert2 cert was empty")
            if cert1_key == cert2_key:
              raise Exception("Cert1 key and cert2 key are the same")
            if cert1_cert == cert2_cert:
              raise Exception("Cert1 cert and cert2 cert are the same")

        with subtest("Fail if certificate is not in CA bundle"):
            server.fail("curl --cacert /etc/static/ssl/certs/ca-bundle.crt --fail-with-body -v https://example.com")
            server.fail("curl --cacert /etc/static/ssl/certs/ca-bundle.crt --fail-with-body -v https://subdomain.example.com")
            server.fail("curl --cacert /etc/static/ssl/certs/ca-certificates.crt --fail-with-body -v https://example.com")
            server.fail("curl --cacert /etc/static/ssl/certs/ca-certificates.crt --fail-with-body -v https://subdomain.example.com")

        with subtest("Idempotency"):
            server.succeed("systemctl restart shb-certs-ca-myca")
            server.succeed("systemctl restart shb-certs-cert-selfsigned-cert1")
            server.succeed("systemctl restart shb-certs-cert-selfsigned-cert2")

            new_myca_key = server.succeed("cat {}".format("${myca.paths.key}")).strip();
            new_myca_cert = server.succeed("cat {}".format("${myca.paths.cert}")).strip();
            new_cert1_key = server.succeed("cat {}".format("${cert1.paths.key}")).strip();
            new_cert1_cert = server.succeed("cat {}".format("${cert1.paths.cert}")).strip();
            new_cert2_key = server.succeed("cat {}".format("${cert2.paths.key}")).strip();
            new_cert2_cert = server.succeed("cat {}".format("${cert2.paths.cert}")).strip();
            new_ca_bundle = server.succeed("cat /etc/ssl/certs/ca-bundle.crt").strip();
            if new_myca_key != myca_key:
                raise Exception("New CA key is different from old one.")
            if new_myca_cert != myca_cert:
                raise Exception("New CA cert is different from old one.")
            if new_cert1_key != cert1_key:
                raise Exception("New Cert1 key is different from old one.")
            if new_cert1_cert != cert1_cert:
                raise Exception("New Cert1 cert is different from old one.")
            if new_cert2_key != cert2_key:
                raise Exception("New Cert2 key is different from old one.")
            if new_cert2_cert != cert2_cert:
                raise Exception("New Cert2 cert is different from old one.")
            if new_ca_bundle != ca_bundle:
                raise Exception("New CA bundle is different from old one.")
      '';
  };
}
