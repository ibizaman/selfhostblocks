{ pkgs
, utils
}:
{ ingress ? 18005
, user ? "vaultwarden"
, group ? "vaultwarden"

, distribution ? {}
}:
let
  addressOrLocalhost = distHaproxy: service:
    if (builtins.head distHaproxy).properties.hostname == service.target.properties.hostname then
      "127.0.0.1"
    else
      service.target.properties.hostname;
in
{
  inherit user group;

  haproxy = service: {
    frontend = {
      acl = {
        acl_vaultwarden = "hdr_beg(host) vaultwarden.";
      };
      use_backend = "if acl_vaultwarden";
    };
    backend = {
      servers = [
        {
          name = "ttrss1";
          address = "${addressOrLocalhost distribution.HaproxyConfig service}:${builtins.toString ingress}";
        }
      ];
    };
  };
}