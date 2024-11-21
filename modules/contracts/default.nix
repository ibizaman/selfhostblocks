{ pkgs, lib }:
let
  inherit (lib) mkOption optionalAttrs;
  inherit (lib.types) anything;

  mkContractFunctions =
    { mkRequest,
      mkResult,
    }: {
      mkRequester = requestCfg: {
        request = mkRequest requestCfg;

        result = mkResult {};
      };

      mkProvider =
        { resultCfg,
          settings ? {},
        }: {
          request = mkRequest {};

          result = mkResult resultCfg;
        } // optionalAttrs (settings != {}) { inherit settings; };

      contract = {
        request = mkRequest {};

        result = mkResult {};

        settings = mkOption {
          description = ''
          Optional attribute set with options specific to the provider.
          '';
          type = anything;
        };
      };
    };
in
{
  inherit mkContractFunctions;

  databasebackup = import ./databasebackup.nix { inherit lib; };
  backup = import ./backup.nix { inherit lib; };
  mount = import ./mount.nix { inherit lib; };
  secret = import ./secret.nix { inherit pkgs lib; };
  ssl = import ./ssl.nix { inherit lib; };
  test = {
    secret = import ./secret/test.nix { inherit pkgs lib; };
    databasebackup = import ./databasebackup/test.nix { inherit pkgs lib; };
    backup = import ./backup/test.nix { inherit pkgs lib; };
  };
}
