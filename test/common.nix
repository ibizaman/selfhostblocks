{
  lib,
}:
{
  accessScript = {
    subdomain
    , domain
    , hasSSL
    , waitForServices ? s: []
    , waitForPorts ? p: []
    , waitForUnixSocket ? u: []
    , extraScript ? {...}: ""
    , redirectSSO ? false
  }: { nodes, ... }:
    let
      fqdn = "${subdomain}.${domain}";
      proto_fqdn = if hasSSL args then "https://${fqdn}" else "http://${fqdn}";

      args = {
        node.name = "server";
        node.config = nodes.server;
        inherit proto_fqdn;
      };
    in
    ''
    import json
    import os
    import pathlib

    start_all()
    ''
    + lib.strings.concatMapStrings (s: ''server.wait_for_unit("${s}")'' + "\n") (
      waitForServices args
      ++ (lib.optionals redirectSSO [ "authelia-auth.${domain}.service" ])
    )
    + lib.strings.concatMapStrings (p: ''server.wait_for_open_port(${toString p})'' + "\n") (
      waitForPorts args
      ++ (lib.optionals redirectSSO [ nodes.server.services.authelia.instances."auth.${domain}".settings.server.port ] )
    )
    + lib.strings.concatMapStrings (u: ''server.wait_for_open_unix_socket("${u}")'' + "\n") (waitForUnixSocket args)
    + ''
    if ${if hasSSL args then "True" else "False"}:
        server.copy_from_vm("/etc/ssl/certs/ca-certificates.crt")
        client.succeed("rm -r /etc/ssl/certs")
        client.copy_from_host(str(pathlib.Path(os.environ.get("out", os.getcwd())) / "ca-certificates.crt"), "/etc/ssl/certs/ca-certificates.crt")

    def curl(target, format, endpoint, data="", extra=""):
        cmd = ("curl --show-error --location"
              + " --cookie-jar cookie.txt"
              + " --cookie cookie.txt"
              + " --connect-to ${fqdn}:443:server:443"
              + " --connect-to ${fqdn}:80:server:80"
              # Client must be able to resolve talking to auth server
              + " --connect-to auth.${domain}:443:server:443"
              + (f" --data '{data}'" if data != "" else "")
              + (f" --silent --output /dev/null --write-out '{format}'" if format != "" else "")
              + (f" {extra}" if extra != "" else "")
              + f" {endpoint}")
        print(cmd)
        _, r = target.execute(cmd)
        # print(r)
        return json.loads(r)

    def unline_with(j, s):
        return j.join((x.strip() for x in s.split("\n")))

    ''
    + (if (! redirectSSO) then ''
    with subtest("access"):
        response = curl(client, """{"code":%{response_code}}""", "${proto_fqdn}")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")
    '' else ''
    with subtest("unauthenticated access is not granted"):
        response = curl(client, """{"code":%{response_code},"auth_host":"%{urle.host}","auth_query":"%{urle.query}","all":%{json}}""", "${proto_fqdn}")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")
        if response['auth_host'] != "auth.${domain}":
            raise Exception(f"auth host should be auth.${domain} but is {response['auth_host']}")
        if response['auth_query'] != "rd=${proto_fqdn}/":
            raise Exception(f"auth query should be rd=${proto_fqdn}/ but is {response['auth_query']}")
    ''
    )
    + (let
      script = extraScript args;
      indent = i: str: lib.concatMapStringsSep "\n" (x: (lib.strings.replicate i " ") + x) (lib.splitString "\n" script);
    in
      lib.optionalString (script != "") ''
        with subtest("extraScript"):
        ${indent 4 script}
      '');

  base = pkgs: additionalModules: {
    imports = [
      (pkgs.path + "/nixos/modules/profiles/headless.nix")
      (pkgs.path + "/nixos/modules/profiles/qemu-guest.nix")
      # TODO: replace this option by the backup contract
      {
        options = {
          shb.backup = lib.mkOption { type = lib.types.anything; };
        };
      }
      # TODO: replace postgresql.nix and authelia.nix by the sso contract
      ../modules/blocks/postgresql.nix
      ../modules/blocks/authelia.nix
      ../modules/blocks/nginx.nix
    ] ++ additionalModules;

    # Nginx port.
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };

  certs = domain: { config, ... }: {
    imports = [
      ../modules/blocks/ssl.nix
    ];

    shb.certs = {
      cas.selfsigned.myca = {
        name = "My CA";
      };
      certs.selfsigned = {
        n = {
          ca = config.shb.certs.cas.selfsigned.myca;
          domain = "*.${domain}";
          group = "nginx";
        };
      };
    };

    systemd.services.nginx.after = [ config.shb.certs.certs.selfsigned.n.systemdService ];
    systemd.services.nginx.requires = [ config.shb.certs.certs.selfsigned.n.systemdService ];
  };

  ldap = domain: pkgs: {
    imports = [
      ../modules/blocks/ldap.nix
    ];

    networking.hosts = {
      "127.0.0.1" = [ "ldap.${domain}" ];
    };

    shb.ldap = {
      enable = true;
      inherit domain;
      subdomain = "ldap";
      ldapPort = 3890;
      webUIListenPort = 17170;
      dcdomain = "dc=example,dc=com";
      ldapUserPasswordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
      jwtSecretFile = pkgs.writeText "jwtSecret" "jwtSecret";
    };
  };

  sso = domain: pkgs: ssl: { config, ... }: {
    imports = [
      ../modules/blocks/authelia.nix
    ];

    networking.hosts = {
      "127.0.0.1" = [ "auth.${domain}" ];
    };

    shb.authelia = {
      enable = true;
      inherit domain;
      subdomain = "auth";
      ssl = config.shb.certs.certs.selfsigned.n;

      ldapEndpoint = "ldap://127.0.0.1:${builtins.toString config.shb.ldap.ldapPort}";
      dcdomain = config.shb.ldap.dcdomain;

      secrets = {
        jwtSecretFile = pkgs.writeText "jwtSecret" "jwtSecret";
        ldapAdminPasswordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
        sessionSecretFile = pkgs.writeText "sessionSecret" "sessionSecret";
        storageEncryptionKeyFile = pkgs.writeText "storageEncryptionKey" "storageEncryptionKey";
        identityProvidersOIDCHMACSecretFile = pkgs.writeText "identityProvidersOIDCHMACSecret" "identityProvidersOIDCHMACSecret";
        identityProvidersOIDCIssuerPrivateKeyFile = (pkgs.runCommand "gen-private-key" {} ''
          mkdir $out
          ${pkgs.openssl}/bin/openssl genrsa -out $out/private.pem 4096
        '') + "/private.pem";
      };
    };
  };

}
