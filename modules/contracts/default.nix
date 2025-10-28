{ pkgs, lib }:
let
  inherit (lib) mkOption optionalAttrs;
  inherit (lib.types) anything;

  mkContractFunctions =
    {
      mkRequest,
      mkResult,
    }:
    {
      mkRequester = requestCfg: {
        request = mkRequest requestCfg;

        result = mkResult { };
      };

      mkProvider =
        {
          resultCfg,
          settings ? { },
        }:
        {
          request = mkRequest { };

          result = mkResult resultCfg;
        }
        // optionalAttrs (settings != { }) { inherit settings; };

      contract = {
        request = mkRequest { };

        result = mkResult { };

        settings = mkOption {
          description = ''
            Optional attribute set with options specific to the provider.
          '';
          type = anything;
        };
      };
    };

  importContract =
    module:
    let
      importedModule = pkgs.callPackage module { };
    in
    mkContractFunctions {
      inherit (importedModule) mkRequest mkResult;
    };
in
{
  databasebackup = importContract ./databasebackup.nix;
  backup = importContract ./backup.nix;
  mount = pkgs.callPackage ./mount.nix { };
  secret = importContract ./secret.nix;
  ssl = pkgs.callPackage ./ssl.nix { };
  test = {
    secret = pkgs.callPackage ./secret/test.nix { };
    databasebackup = pkgs.callPackage ./databasebackup/test.nix { };
    backup = pkgs.callPackage ./backup/test.nix { };
  };
}
