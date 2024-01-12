{ lib }:
{
  ssl = import ./ssl.nix { inherit lib; };
}
