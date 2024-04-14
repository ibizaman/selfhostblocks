# SSL Generator Contract {#ssl-contract}

This NixOS contract represents an SSL certificate generator. This contract is used to decouple
generating an SSL certificate from using it. In practice, you can swap generators without updating
modules depending on it.

## Contract Reference {#ssl-contract-options}

These are all the options that are expected to exist for this contract to be respected.

```{=include=} options
id-prefix: contracts-ssl-options-
list-id: selfhostblocks-options
source: @OPTIONS_JSON@
```

## Usage {#ssl-contract-usage}

Let's assume a module implementing this contract is available under the `ssl` variable:

```nix
let
  ssl = <...>;
in
```

To use this module, we can reference the path where the certificate and the private key are located with:

```nix
ssl.paths.cert
ssl.paths.key
```

We can then configure Nginx to use those certificates:

```nix
services.nginx.virtualHosts."example.com" = {
  onlySSL = true;
  sslCertificate = ssl.paths.cert;
  sslCertificateKey = ssl.paths.key;

  locations."/".extraConfig = ''
    add_header Content-Type text/plain;
    return 200 'It works!';
  '';
};
```

To make sure the Nginx webserver can find the generated file, we will make it wait for the
certificate to the generated:

```nix
systemd.services.nginx = {
  after = [ ssl.systemdService ];
  requires = [ ssl.systemdService ];
};
```

## Provided Implementations {#ssl-contract-impl-shb}

Multiple implementation are provided out of the box at [SSL block](blocks-ssl.html).

## Custom Implementation {#ssl-contract-impl-custom}

To implement this contract, you must create a module that respects this contract. The following
snippet shows an example.

```nix
{ lib, ... }:
{
  options.my.generator = {
    paths = lib.mkOption {
      description = ''
        Paths where certs will be located.

        This option implements the SSL Generator contract.
      '';
      type = contracts.ssl.certs-paths;
      default = {
        key = "/var/lib/my_generator/key.pem";
        cert = "/var/lib/my_generator/cert.pem";
      };
    };

    systemdService = lib.mkOption {
      description = ''
        Systemd oneshot service used to generate the certs.

        This option implements the SSL Generator contract.
      '';
      type = lib.types.str;
      default = "my-generator.service";
    };

    # Other options needed for this implementation
  };

  config = {
    # custom implementation goes here
  };
}
```

You can then create an instance of this generator:

```nix
{
  my.generator = ...;
}
```

And use it whenever a module expects something implementing this SSL generator contract:

```nix
{ config, ... }:
{
  my.service.ssl = config.my.generator;
}
```
