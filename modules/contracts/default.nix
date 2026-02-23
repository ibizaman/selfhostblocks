{
  pkgs,
  lib,
  shb,
}:
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
      importedModule = pkgs.callPackage module {
        shb = shb // {
          inherit contracts;
        };
      };
    in
    mkContractFunctions {
      inherit (importedModule) mkRequest mkResult;
    };

  contracts = {
    databasebackup = importContract ./databasebackup.nix;
    dashboard = importContract ./dashboard.nix;
    backup = importContract ./backup.nix;
    mount = pkgs.callPackage ./mount.nix { };
    secret = importContract ./secret.nix;
    ssl = pkgs.callPackage ./ssl.nix { };
    test = {
      secret = pkgs.callPackage ./secret/test.nix { inherit shb; };
      databasebackup = pkgs.callPackage ./databasebackup/test.nix { inherit shb; };
      backup = pkgs.callPackage ./backup/test.nix { inherit shb; };
    };
  };
in
contracts
