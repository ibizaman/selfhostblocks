# Mitmdump Block {#blocks-mitmdump}

Defined in [`/modules/blocks/mitmdump.nix`](@REPO@/modules/blocks/mitmdump.nix).

This block sets up an [Mitmdump][] service in [reverse proxy][] mode.
In other words, you can put this block between a client and a server to inspect all the network traffic.

[Mitmdump]: https://plattner.me/mp-docs/#mitmdump
[reverse proxy]: https://plattner.me/mp-docs/concepts-modes/#reverse-proxy

Multiple instances of mitmdump all listening on different ports
and proxying to different upstream servers can be created.

The systemd service is made so it is started only when the mitmdump instance
has started listening on the expected port.

Also, addons can be enabled with the `enabledAddons` option.

## Usage {#blocks-mitmdump-usage}

Put mitmdump in front of a HTTP server listening on port 8000 on the same machine:

```nix
shb.mitmdump.instances."my-instance" = {
  listenPort = 8001;
  upstreamHost = "http://127.0.0.1";
  upstreamPort = 8000;
  after = [ "server.service" ];
};
```

`upstreamHost` has its default value here and can be left out.

Put mitmdump in front of a HTTP server listening on port 8000 on another machine:

```nix
shb.mitmdump.instances."my-instance" = {
  listenPort = 8001;
  upstreamHost = "http://otherhost";
  upstreamPort = 8000;
  after = [ "server.service" ];
};
```

### Handle Upstream TLS {#blocks-mitmdump-usage-https}

Replace `http` with `https` if the server expects an HTTPS connection.

### Accept Connections from Anywhere {#blocks-mitmdump-usage-anywhere}

By default, `mitmdump` is configured to listen only for connections from localhost.
Add `listenHost=0.0.0.0` to make `mitmdump` accept connections from anywhere.

### Extra Logging {#blocks-mitmdump-usage-logging}

To print request and response bodies and more, increase the logging with:

```nix
extraArgs = [
    "--set" "flow_detail=3"
    "--set" "content_view_lines_cutoff=2000"
];
```

The default `flow_details` is 1. See the [manual][] for more explanations on the option.

[manual]: (https://docs.mitmproxy.org/stable/concepts/options/#flow_detail)

This will change the verbosity for all requests and responses.
If you need more fine grained logging, configure instead the [Logger Addon][].

[Logger Addon]: #blocks-mitmdump-addons-logger

## Addons {#blocks-mitmdump-addons}

All provided addons can be found under the `shb.mitmproxy.addons` option.

To enable one for an instance, add it to the `enabledAddons` option. For example:

```nix
shb.mitmdump.instances."my-instance" = {
    enabledAddons = [ config.shb.mitmdump.addons.logger ]
}
```

### Fine Grained Logger {#blocks-mitmdump-addons-logger}

The Fine Grained Logger addon is found under `shb.mitmproxy.addons.logger`.
Enabling this addon will add the `mitmdump` option `verbose_pattern` which takes a regex and if it matches,
prints the request and response headers and body.
If it does not match, it will just print the response status.

For example, with the `extraArgs`:

```nix
extraArgs = [
  "--set" "verbose_pattern=/verbose"
];
```

A `GET` request to `/notverbose` will print something similar to:

```
mitmdump[972]: 127.0.0.1:53586: GET http://127.0.0.1:8000/notverbose HTTP/1.1
mitmdump[972]:      << HTTP/1.0 200 OK 16b
```

While a `GET` request to `/verbose` will print something similar to:

```
mitmdump[972]: [22:42:58.840]
mitmdump[972]: RequestHeaders:
mitmdump[972]:     Host: 127.0.0.1:8000
mitmdump[972]:     User-Agent: curl/8.14.1
mitmdump[972]:     Accept: */*
mitmdump[972]: RequestBody:
mitmdump[972]: Status:          200
mitmdump[972]: ResponseHeaders:
mitmdump[972]:     Server: BaseHTTP/0.6 Python/3.13.4
mitmdump[972]:     Date: Sun, 03 Aug 2025 22:42:58 GMT
mitmdump[972]:     Content-Type: text/plain
mitmdump[972]:     Content-Length: 13
mitmdump[972]: ResponseBody:    test2/verbose
mitmdump[972]: 127.0.0.1:53602: GET http://127.0.0.1:8000/verbose HTTP/1.1
mitmdump[972]:      << HTTP/1.0 200 OK 13b
```

## Example {#blocks-mitmdump-example}

Let's assume a server is listening on port 8000
which responds a plain text response `test1`
and its related systemd service is named `test1.service`.
Sorry, creative naming is not my forte.

Let's put an mitmdump instance in front of it, like so:

```nix
shb.mitmdump.instances."test1" = {
  listenPort = 8001;
  upstreamPort = 8000;
  after = [ "test1.service" ];
  extraArgs = [
    "--set" "flow_detail=3"
    "--set" "content_view_lines_cutoff=2000"
  ];
};
```

This creates an `mitmdump-test1.service` systemd service.
We can then use `journalctl -u mitmdump-test1.service` to see the output.

If we make a `curl` request to it: `curl -v http://127.0.0.1:8001`,
we will get the following output:

```
mitmdump-test1[971]: 127.0.0.1:40878: GET http://127.0.0.1:8000/ HTTP/1.1
mitmdump-test1[971]:     Host: 127.0.0.1:8000
mitmdump-test1[971]:     User-Agent: curl/8.14.1
mitmdump-test1[971]:     Accept: */*
mitmdump-test1[971]:  << HTTP/1.0 200 OK 5b
mitmdump-test1[971]:     Server: BaseHTTP/0.6 Python/3.13.4
mitmdump-test1[971]:     Date: Thu, 31 Jul 2025 20:55:16 GMT
mitmdump-test1[971]:     Content-Type: text/plain
mitmdump-test1[971]:     Content-Length: 5
mitmdump-test1[971]:     test1
```

## Tests {#blocks-mitmdump-tests}

Specific integration tests are defined in [`/test/blocks/mitmdump.nix`](@REPO@/test/blocks/mitmdump.nix).

## Options Reference {#blocks-mitmdump-options}

```{=include=} options
id-prefix: blocks-mitmdump-options-
list-id: selfhostblocks-block-mitmdump-options
source: @OPTIONS_JSON@
```
