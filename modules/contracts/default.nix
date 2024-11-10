{ pkgs, lib }:
{
  databasebackup = import ./databasebackup.nix { inherit lib; };
  backup = import ./backup.nix { inherit lib; };
  mount = import ./mount.nix { inherit lib; };
  secret = import ./secret.nix { inherit lib; };
  ssl = import ./ssl.nix { inherit lib; };
  test = {
    secret = import ./secret/test.nix { inherit pkgs lib; };
    databasebackup = import ./databasebackup/test.nix { inherit pkgs lib; };
  };
}
