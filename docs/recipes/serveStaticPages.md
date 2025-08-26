<!-- Read these docs at https://shb.skarabox.com -->
# Serve Static Pages {#recipes-serveStaticPages}

This recipe shows how to use SelfHostBlocks blocks to serve static web pages using the Nginx reverse proxy with SSL termination.

In this recipe, we'll assume the pages to serve are found under the `/srv/my-website` path and will be served under the `my-website.example.com` fqdn.

```nix
let
  name = "my-website";
  subdomain = name;
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";
  user = "me";
in
```

We also assume the static web pages are owned and updated by the user named `me`.

## ZFS dataset {#recipes-serveStaticPages-zfs}

We can create a ZFS dataset with:

```nix
shb.zfs.datasets."safe/${name}".path = "/srv/${name}";
```

## SSL Certificate {#recipes-serveStaticPages-ssl}

Requesting an SSL certificate from Let's Encrypt is done by adding an entry to
the `extraDomains` option:

```nix
shb.certs.certs.letsencrypt.${domain}.extraDomains = [ fqdn ];
```

This assumes the `shb.certs` block has been configured:

```nix
shb.certs.certs.letsencrypt.${domain} = {
  inherit domain;
  group = "nginx";
  reloadServices = [ "nginx.service" ];
  adminEmail = "admin@${domain}";
};
```

## Reverse Proxy {#recipes-serveStaticPages-nginx}

First, we make the parent directory owned by the user which will upload them and `nginx`:

```nix
systemd.tmpfiles.rules = lib.mkBefore [
  "d '/srv/${name}' 0750 ${user} nginx - -"
];
```

Now, we can setup nginx. The following snippet serves files from the `/srv/${name}/` directory.

```nix
services.nginx.enable = true;

services.nginx.virtualHosts."skarabox.${domain}" = {
  forceSSL = true;
  sslCertificate = config.shb.certs.certs.letsencrypt."${domain}".paths.cert;
  sslCertificateKey = config.shb.certs.certs.letsencrypt."${domain}".paths.key;
  locations."/" = {
    root = "/srv/${name}/";
    extraConfig = ''
      add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
      add_header Cache-Control "max-age=604800, stale-while-revalidate=86400, stale-if-error=86400, must-revalidate, public";
    '';
  };
};
```
