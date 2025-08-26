<!-- Read these docs at https://shb.skarabox.com -->
# Expose a service {#recipes-exposeService}

Let's see how one can use most of the blocks provided by SelfHostBlocks to make a service
accessible through a reverse proxy with LDAP and SSO integration as well as backing up
this service and creating a ZFS dataset to store the service's data.

We'll use an hypothetical well made service found under `services.awesome` as our example.
We're purposely not using a real service to avoid needing to deal with uninteresting particularities.

## Service setup {#recipes-exposeService-service}

Let's say our domain name is `example.com`,
and we want to reach our service under the `awesome` subdomain:

```nix
let
  domain = "example.com";
  subdomain = "awesome";
  fqdn = "${subdomain}.${domain}";
  listenPort = 9000;
  dataDir = "/var/lib/awesome";
in
```

We then `enable` the service and explicitly set the `listenPort` and `dataDir`,
assuming those options exist:

```nix
services.awesome = {
  enable = true;
  inherit dataDir listenPort;
};
```

## SSL Certificate {#recipes-exposeService-ssl}

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

## LDAP group {#recipes-exposeService-ldap}

We want only users of the group `calibre_user` to be able to access this subdomain.
The following snippet creates the LDAP group:

```nix
shb.lldap.ensureGroups = {
  calibre_user = {};
};
```

## Reverse Proxy with Forward Auth {#recipes-exposeService-nginx}

If our service does not integrate with OIDC, we can still protect it with SSO
with forward authentication by letting the reverse proxy handle authentication.
This is done by adding an entry to `shb.nginx.vhosts`:

```nix
shb.nginx.vhosts = [
  {
    inherit subdomain domain;
    ssl = config.shb.certs.certs.letsencrypt.${domain};
    upstream = "http://127.0.0.1:${toString config.services.calibre-web.listen.port}";
    authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    autheliaRules = [{
      policy = "one_factor";
      subject = [ "group:${config.shb.lldap.ensureGroups.calibre_user.name}" ];
    }];
  }
];
```

## ZFS support {#recipes-exposeService-zfs}

If you use ZFS, you can use SelfHostBlocks to create a dataset for you:

```nix
shb.zfs.datasets."safe/awesome".path = config.services.awesome.dataDir;
```

## Debugging {#recipes-exposeService-debug}

Usually, the log level of the service can be increased with some option they provide.

With SelfHostBlocks, you can also introspect any HTTP service by adding an
`mitmdump` instance between the reverse proxy and the `awesome` service:

```nix
shb.mitmdump.awesome = {
  inherit listenPort;
  upstreamPort = listenPort + 1;
};
services.awesome.listenPort = lib.mkForce (listenPort + 1);
```

This creates a `mitmdump-awesome.service` systemd service which prints the requests' and responses' headers and bodies.

## Backup {#recipes-exposeService-backup}

The following snippet uses the `shb.restic` block to backup the `services.awesome.dataDir` directory:

```nix
shb.restic.instances.awesome = {
  request.user = "awesome";
  request.sourceDirectories = [ dataDir ];
  settings.enable = true;
  settings.passphrase.result = config.shb.sops.secret.awesome.result;
  settings.repository.path = "/srv/backup/awesome";
};

shb.sops.secret."awesome" = {
  request = config.shb.restic.instances.awesome.settings.passphrase.request;
};
```
