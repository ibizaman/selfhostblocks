# Mitmdump Block {#blocks-mitmdump}

Defined in [`/modules/blocks/authelia.nix`](@REPO@/modules/blocks/authelia.nix).

This block sets up an [Mitmdump][] service in [reverse proxy][] mode.
In other words, you can put this block between a client and a server to inspect all the network traffic.

[Mitmdump]: https://plattner.me/mp-docs/#mitmdump
[reverse proxy]: https://plattner.me/mp-docs/concepts-modes/#reverse-proxy

Multiple instances of mitmdump all listening on different ports
and proxying to different upstream servers can be created.

The systemd service is made so it is started only when the mitmdump instance
has started listening on the expected port.

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

`upstreamHost` is the default here and can be left out.

Put mitmdump in front of a HTTP server listening on port 8000 on another machine:

```nix
shb.mitmdump.instances."my-instance" = {
  listenPort = 8001;
  upstreamHost = "http://otherhost";
  upstreamPort = 8000;
  after = [ "server.service" ];
};
```

Replace `http` with `https` if the server expects an HTTPS connection.

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
