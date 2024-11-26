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

  importContract = module:
    let
      importedModule = pkgs.callPackage module {};
    in
      mkContractFunctions {
        inherit (importedModule) mkRequest mkResult;
      };
in
{
  databasebackup = importContract ./databasebackup.nix;
  backup = importContract ./backup.nix;
  mount = import ./mount.nix { inherit lib; };
  secret = importContract ./secret.nix;
  ssl = import ./ssl.nix { inherit lib; };
  test = {
    secret = import ./secret/test.nix { inherit pkgs lib; };
    databasebackup = import ./databasebackup/test.nix { inherit pkgs lib; };
    backup = import ./backup/test.nix { inherit pkgs lib; };
  };
}
