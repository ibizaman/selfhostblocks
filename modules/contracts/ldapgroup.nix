{ pkgs, lib, ... }:
let
  inherit (lib) literalMD mkOption optionalAttrs optionalString;
  inherit (lib.types) str submodule;

  shblib = pkgs.callPackage ../../lib {};
  inherit (shblib) anyNotNull;
in
{
  mkRequest = {
    name ? "",
    nameText ? null,
  }: mkOption {
    description = ''
      Request part of the ldap group contract.

      Options set by the requester module
      enforcing what properties the group should have.

      This is intentionally empty as the only required property
      is the existence of this option.
    '';
    default = {
      inherit name;
    };
    defaultText = optionalString (anyNotNull [
      nameText
    ]) (literalMD ''
    {
      name = ${if nameText != null then nameText else name};
    }
    '');

    type = submodule {
      options = {
        name = mkOption {
          description = ''
            Name of the LDAP group.
          '';
          type = str;
          default = name;
        } // optionalAttrs (nameText != null) {
          defaultText = literalMD nameText;
        };
      };
    };
  };

  mkResult = {
    name ? "",
    nameText ? null,
  }: mkOption {
    description = ''
      Result part of the ldap group contract.

      Options set by the provider module that indicates the name of the group and other properties.
    '';
    default = {
      inherit name;
    };
    defaultText = optionalString (anyNotNull [
      nameText
    ]) (literalMD ''
    {
      name = ${if nameText != null then nameText else name};
    }
    '');

    type = submodule {
      options = {
        name = mkOption {
          description = ''
            Name of the LDAP group.
          '';
          type = str;
          default = name;
        } // optionalAttrs (nameText != null) {
          defaultText = literalMD nameText;
        };
      };
    };
  };
}
