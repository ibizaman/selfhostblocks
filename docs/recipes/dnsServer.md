<!-- Read these docs at https://shb.skarabox.com -->
# Self-Host a DNS server making {#recipes-dnsServer}

This recipe will show how to setup [dnsmasq][] as a local DNS server
that forwards all queries to your own domain `example.com` to a local IP - your server running SelfHostBlocks for example.

[dnsmasq]: https://dnsmasq.org/doc.html

Other DNS queries will be forwarded to an external DNS server
using [DNSSEC][] to encrypt your queries.

[DNSSEC]: https://en.wikipedia.org/wiki/Domain_Name_System_Security_Extensions

For this to work, you must configure the DHCP server of your network
to set the DNS server to the IP of the host where the DNS server is running.
Usually, your ISP's router can do this but probably easier is to disable completely that DHCP server
and also self-host the DHCP server.
This recipe shows how to do that too.

## Why {#recipes-dnsServer-why}

_You want to hide your DNS queries from your ISP or other prying eyes._

Even if you use HTTPS to access an URL,
DNS queries are by default made in plain text.
Crazy, right?
So, even if the actual communication is encrypted,
everyone can see which site you're trying to access.
Using DNSSEC means encrypting the traffic to your preferred external DNS server.
Of course, that server will see what domain names you're trying to resolve,
but at least intermediary hops will not be able to anymore.

_You want more control on which DNS queries can be made._

Self-hosting your own DNS server means you can block some domains or subdomains.
This is done in practice by instructing your DNS server
to fail resolving some domains or subdomains.
Want to block Facebook for every host in the house?
That's the way to go.

Some routers allow this level of fine-tuning but if not,
self-hosting your own DNS server is the way to go.

## Drawbacks {#recipes-dnsServer-drawbacks}

Although it has some nice advantages,
self-hosting your own DNS server has one major drawback:
if it goes down, the whole household will be impacted.
By experience, it takes up to 5 minutes for others to notice something is wrong with internet.

So be wary when you deploy a new config.

## Recipe {#recipes-dnsServer-recipe}

The following snippet:

- Opens UDP port 53 in the firewall which is the ubiquitous (and hardcoded, crazy I know) port for DNS queries.
- Disables the default DNS resolver.
- Sets up dnsmasq as the DNS server.
- Optionally sets up dnsmasq as the DHCP server.
- Answers all DNS requests to your domain with the internal IP of the server.
- Forwards all other DNS requests to an external DNS server using DNSSEC.
  This is done using [stubby][].

[stubby]: https://dnsprivacy.org/dns_privacy_daemon_-_stubby/

For more information about options, read the dnsmasq [manual][].

[manual]: https://dnsmasq.org/docs/dnsmasq-man.html

```nix
let
  # Replace these values with what matches your network.
  domain = "example.com";
  serverIP = "192.168.1.30";

  # This port is used internally for dnsmasq to talk to stubby on the loopback interface.
  # Only change this if that port is already taken.
  stubbyPort = 53000;
in
{
  networking.firewall.allowedUDPPorts = [ 53 ];

  services.resolved.enable = false;
  services.dnsmasq = {
    enable = true;
    settings = {
      inherit domain;

      # Redirect queries to the stubby instance.
      server = [
        "127.0.0.1#${stubbyPort}"
        "::1#${stubbyPort}"
      ];
      # We do trust our own instance of stubby
      # so we can proxy DNSSEC stuff.
      # I'm not sure how useful this is.
      proxy-dnssec = true;

      # Log all queries.
      # This produces a lot of log lines
      # and looking at those can be scary!
      log-queries = true;

      # Do not look at /etc/resolv.conf
      no-resolv = true;

      # Do not forward externally reverse DNS lookups for internal IPs.
      bogus-priv = true;

      address = [
        "/.${domain}/${serverIP}"
        # You can redirect anything anywhere too.
        "/pikvm.${domain}/192.168.1.31"
      ];
    };
  };

  services.stubby = {
    enable = true;
    # It's a bit weird but default values comes from the examples settings hosted at
    # https://github.com/getdnsapi/stubby/blob/develop/stubby.yml.example
    settings = pkgs.stubby.passthru.settingsExample // {
      listen_addresses = [
        "127.0.0.1@${stubbyPort}"
        "0::1@${stubbyPort}"
      ];

      # For more example of good DNS resolvers,
      # head to https://dnsprivacy.org/public_resolvers/
      #
      # The digest comes from https://nixos.wiki/wiki/Encrypted_DNS#Stubby
      upstream_recursive_servers = [
        {
          address_data = "9.9.9.9";
          tls_auth_name = "dns.quad9.net";
          tls_pubkey_pinset = [
            {
              digest = "sha256";
              value = "i2kObfz0qIKCGNWt7MjBUeSrh0Dyjb0/zWINImZES+I=";
            }
          ];
        }
        {
          address_data = "149.112.112.112";
          tls_auth_name = "dns.quad9.net";
          tls_pubkey_pinset = [
            {
              digest = "sha256";
              value = "i2kObfz0qIKCGNWt7MjBUeSrh0Dyjb0/zWINImZES+I=";
            }
          ];
        }
      ];
    };
  };
}
```

Optionally, to use dnsmasq as the DHCP server too,
use the following snippet:

```nix
services.dnsmasq = {
  settings = {
    # When switching DNS server, accept old leases from previous server.
    dhcp-authoritative = true;

    # Adapt to your needs
    # <ip-from>,<ip-to>,<mask>,<lease-ttl>
    dhcp-range = "192.168.1.101,192.168.1.150,255.255.255.0,6h";

    # Static DNS leases if needed.
    # Choose an IP outside of the DHCP range
    # <mac-address>,<DNS name>,<ip>,<lease-ttl>
    dhcp-host = [
      "12:34:56:78:9a:bc,server,192.168.1.50,infinite"
    ];

    # Set default route to the router that can acccess the internet.
    dhcp-option = [
      "3,192.168.1.1"
    ];
  };
};
```
