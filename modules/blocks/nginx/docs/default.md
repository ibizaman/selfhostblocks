# Nginx Block {#blocks-nginx}

Defined in [`/modules/blocks/nginx.nix`](@REPO@/modules/blocks/nginx.nix).

This block sets up a [Nginx](https://nginx.org/) instance.

It complements the upstream nixpkgs with some authentication and debugging improvements as shows in the Usage section.

## Usage {#blocks-nginx-usage}

### Access Logging {#blocks-nginx-usage-accesslog}

JSON access logging is enabled with the [`shb.nginx.accessLog`](#blocks-nginx-options-shb.nginx.accessLog) option:

```nix
{
  shb.nginx.accessLog = true;
}
```

Looking at the systemd logs (`journalctl -fu nginx`) will show for example:

```json
nginx[969]: server nginx:
  {
    "remote_addr":"192.168.1.1",
    "remote_user":"-",
    "time_local":"29/Dec/2025:14:22:41 +0000",
    "request":"POST /api/firstfactor HTTP/2.0",
    "request_length":"264",
    "server_name":"auth_example_com",
    "status":"200",
    "bytes_sent":"855",
    "body_bytes_sent":"60",
    "referrer":"-",
    "user_agent":"Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0",
    "gzip_ration":"-",
    "post":"{\x22username\x22:\x22charlie\x22,\x22password\x22:\x22CharliePassword\x22,\x22keepMeLoggedIn\x22:false,\x22targetURL\x22:\x22https://f.example.com/\x22,\x22requestMethod\x22:null}",
    "upstream_addr":"127.0.0.1:9091",
    "upstream_status":"200",
    "request_time":"0.873",
    "upstream_response_time":"0.873",
    "upstream_connect_time":"0.001",
    "upstream_header_time":"0.872"
  }
```

This _will_ log the body of POST queries so it should only be enabled for debug logging.

### Debug Logging {#blocks-nginx-usage-debuglog}

Debug logging is enabled with the [`shb.nginx.debugLog`](#blocks-nginx-options-shb.nginx.debugLog) option:

```nix
{
  shb.nginx.debugLog = true;
}
```

If enabled, it sets:

```
error_log stderr warn;
```

### Virtual Host Upstream Proxy {#blocks-nginx-usage-upstream}

Easy upstream proxy setup is done with the [`shb.nginx.vhosts.*.upstream`](#blocks-nginx-options-shb.nginx.vhosts._.upstream) option:

```nix
{
  shb.nginx.vhosts = [
    {
      domain = "example.com";
      subdomain = "mysubdomain";
      upstream = "http://127.0.0.1:9090";
    }
  ];
}
```

This will set also a few headers.
Some are shown here and others please see in the [nginx](@REPO@/modules/blocks/nginx.nix) module:

- `Host` = `$host`;
- `X-Real-IP` = `$remote_addr`;
- `X-Forwarded-For` = `$proxy_add_x_forwarded_for`;
- `X-Forwarded-Proto` = `$scheme`;

### Virtual Host SSL Generator Contract Integration {#blocks-nginx-usage-ssl}

This module integrates with the [SSL Generator Contract](./contracts-ssl.html)
to setup HTTPs with the [`shb.nginx.vhosts.*.ssl`](#blocks-nginx-options-shb.nginx.vhosts._.ssl) option:

```nix
{
  shb.nginx.vhosts = [
    {
      domain = "example.com";
      subdomain = "mysubdomain";
      ssl = config.shb.certs.certs.letsencrypt.${domain};;
    }
  ];

  shb.certs.certs.letsencrypt.${domain} = {
    inherit domain;
  };
}
```

### Virtual Host SHB Forward Authentication {#blocks-nginx-usage-shbforwardauth}

For services provided by SelfHostBlocks that do not handle [OIDC integration][OIDC],
this block can provide [forward authentication][] which still allows the service
to still be protected by an SSO server.

[OIDC]: blocks-authelia.html#blocks-authelia-shb-oidc

The user could still be required to authenticate to the service itself,
although some services can automatically users authorized by Authelia.

[forward authentication]: https://doc.traefik.io/traefik/middlewares/http/forwardauth/

Integrating with this block is done with the following code:

```nix
shb.<services>.authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
```

### Virtual Host Forward Authentication {#blocks-nginx-usage-forwardauth}

Forward authentication is when Nginx talks with the SSO service directly
and the user is authenticated before reaching the upstream application.

The SSO service responds with the username, group and more information about the user.
This is then forwarded to the upstream application by Nginx.

Note that _every_ request is authenticated this way with the SSO server
so it involves more hops than a direct [OIDC integration](blocks-authelia.html#blocks-authelia-shb-oidc).

```nix
{
  shb.nginx.vhosts = [
    {
      domain = "example.com";
      subdomain = "mysubdomain";
      authEndpoint = "authelia.example.com";
      autheliaRules = [
        [
          # Protect /admin endpoint with 2FA
          # and only allow access to admin users.
          {
            domain = "myapp.example.com";
            policy = "two_factor";
            subject = [ "group:service_admin" ];
            resources = [
              "^/admin"
            ];
          }
          # Leave /api endpoint open - assumes an API key is used to protect it.
          {
            domain = "myapp.example.com";
            policy = "bypass";
            resources = [
              "^/api"
            ];
          },
          # Protect rest of app with 1FA
          # and allow access to normal and admin users.
          {
            domain = "myapp.example.com";
            policy = "one_factor";
            subject = ["group:service_user"];
          },
        ]
      ];
    }
  ];
}
```

### Virtual Host Extra Config {#blocks-nginx-usage-extraconfig}

To add extra configuration to a virtual host,
use the [`shb.nginx.vhosts.*.extraConfig`](#blocks-nginx-options-shb.nginx.vhosts._.extraConfig) option.
This can be used to add headers, for example:

```nix
{
  shb.nginx.vhosts = [
    {
      domain = "example.com";
      subdomain = "mysubdomain";
      extraConfig = ''
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
      '';
    }
  ];
}
```

## Options Reference {#blocks-nginx-options}

```{=include=} options
id-prefix: blocks-nginx-options-
list-id: selfhostblocks-block-nginx-options
source: @OPTIONS_JSON@
```
