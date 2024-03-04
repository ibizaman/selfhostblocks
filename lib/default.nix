{ pkgs, lib }:
rec {
  replaceSecrets = { userConfig, resultPath, generator }:
    let
      configWithTemplates = withReplacements userConfig;

      nonSecretConfigFile = pkgs.writeText "${resultPath}.template" (generator configWithTemplates);

      replacements = getReplacements userConfig;
    in
      replaceSecretsScript {
        file = nonSecretConfigFile;
        inherit resultPath replacements;
      };

  template = file: newPath: replacements: replaceSecretsScript { inherit file replacements; resultPath = newPath; };
  replaceSecretsScript = { file, resultPath, replacements }:
    let
      templatePath = resultPath + ".template";
      sedPatterns = lib.strings.concatStringsSep " " (lib.attrsets.mapAttrsToList (from: to: "-e \"s|${from}|${to}|\"") replacements);
    in
      ''
      set -euo pipefail
      set -x
      mkdir -p $(dirname ${templatePath})
      ln -fs ${file} ${templatePath}
      rm -f ${resultPath}
      ${pkgs.gnused}/bin/sed ${sedPatterns} ${templatePath} > ${resultPath}
      '';

  secretFileType = lib.types.submodule {
    options = {
      source = lib.mkOption {
        type = lib.types.path;
        description = "File containing the value.";
      };

      transform = lib.mkOption {
        type = lib.types.raw;
        description = "An optional function to transform the secret.";
        default = null;
        example = lib.literalExpression ''
        v: "prefix-$${v}-suffix"
        '';
      };
    };
  };

  secretName = name:
      "%SECRET${lib.strings.toUpper (lib.strings.concatMapStrings (s: "_" + s) name)}%";

  withReplacements = attrs:
    let
      valueOrReplacement = name: value:
        if !(builtins.isAttrs value && value ? "source")
        then value
        else secretName name;
    in
      mapAttrsRecursiveCond (v: ! v ? "source") valueOrReplacement attrs;

  getReplacements = attrs:
    let
      addNameField = name: value:
        if !(builtins.isAttrs value && value ? "source")
        then value
        else value // { name = name; };

      secretsWithName = mapAttrsRecursiveCond (v: ! v ? "source") addNameField attrs;

      allSecrets = collect (v: builtins.isAttrs v && v ? "source") secretsWithName;

      t = { transform ? null, ... }: if isNull transform then x: x else transform;

      genReplacement = secret:
        lib.attrsets.nameValuePair (secretName secret.name) ((t secret) "$(cat ${toString secret.source})");
    in
      lib.attrsets.listToAttrs (map genReplacement allSecrets);
      
  # Inspired lib.attrsets.mapAttrsRecursiveCond but also recurses on lists.
  mapAttrsRecursiveCond =
    # A function, given the attribute set the recursion is currently at, determine if to recurse deeper into that attribute set.
    cond:
    # A function, given a list of attribute names and a value, returns a new value.
    f:
    # Attribute set or list to recursively map over.
    set:
    let
      recurse = path: val:
        if builtins.isAttrs val && cond val
        then lib.attrsets.mapAttrs (n: v: recurse (path ++ [n]) v) val
        else if builtins.isList val && cond val
        then lib.lists.imap0 (i: v: recurse (path ++ [(builtins.toString i)]) v) val
        else f path val;
    in recurse [] set;

  # Like lib.attrsets.collect but also recurses on lists.
  collect =
  # Given an attribute's value, determine if recursion should stop.
  pred:
  # The attribute set to recursively collect.
  attrs:
    if pred attrs then
      [ attrs ]
    else if builtins.isAttrs attrs then
      lib.lists.concatMap (collect pred) (lib.attrsets.attrValues attrs)
    else if builtins.isList attrs then
      lib.lists.concatMap (collect pred) attrs
    else
      [];
}
