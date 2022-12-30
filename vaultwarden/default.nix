{ pkgs
, utils
}:
{ user ? "vaultwarden"
, group ? "vaultwarden"
}:
{
  inherit user group;
}