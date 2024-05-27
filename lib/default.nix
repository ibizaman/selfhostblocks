{ pkgs, lib }:
rec {
  # Replace secrets in a file.
  # - userConfig is an attrset that will produce a config file.
  # - resultPath is the location the config file should have on the filesystem.
  # - generator is a function taking two arguments name and value and returning path in the nix
  #   nix store where the
  replaceSecrets = { userConfig, resultPath, generator }:
    let
      configWithTemplates = withReplacements userConfig;

      nonSecretConfigFile = generator "template" configWithTemplates;

      replacements = getReplacements userConfig;
    in
      replaceSecretsScript {
        file = nonSecretConfigFile;
        inherit resultPath replacements;
      };

  replaceSecretsFormatAdapter = format: format.generate;
  replaceSecretsGeneratorAdapter = generator: name: value: pkgs.writeText "generator " (generator value);

  template = file: newPath: replacements: replaceSecretsScript {
    inherit file replacements;
    resultPath = newPath;
  };

  replaceSecretsScript = { file, resultPath, replacements }:
    let
      templatePath = resultPath + ".template";
      sedPatterns = lib.strings.concatStringsSep " " (lib.attrsets.mapAttrsToList (from: to: "-e \"s|${from}|${to}|\"") replacements);
      sedCmd = if replacements == {}
               then "cat"
               else "${pkgs.gnused}/bin/sed ${sedPatterns}";
    in
      ''
      set -euo pipefail

      mkdir -p $(dirname ${templatePath})
      ln -fs ${file} ${templatePath}
      rm -f ${resultPath}
      ${sedCmd} ${templatePath} > ${resultPath}
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

  # Generator for XML
  formatXML = {
    enclosingRoot ? null
  }: {
    type = with lib.types; let
      valueType = nullOr (oneOf [
        bool
        int
        float
        str
        path
        (attrsOf valueType)
        (listOf valueType)
      ]) // {
        description = "XML value";
      };
    in valueType;

    generate = name: value: pkgs.callPackage ({ runCommand, python3 }: runCommand "config" {
      value = builtins.toJSON (
        if enclosingRoot == null then
          value
        else
          { ${enclosingRoot} = value; });
      passAsFile = [ "value" ];
    } (pkgs.writers.writePython3 "dict2xml" {
      libraries = with python3.pkgs; [ python dict2xml ];
    } ''
      import os
      import json
      from dict2xml import dict2xml

      with open(os.environ["valuePath"]) as f:
          content = json.loads(f.read())
          if content is None:
              print("Could not parse env var valuePath as json")
              os.exit(2)
          with open(os.environ["out"], "w") as out:
              out.write(dict2xml(content))
    '')) {};

  };

  parseXML = xml:
    let
      xmlToJsonFile = pkgs.callPackage ({ runCommand, python3 }: runCommand "config" {
        inherit xml;
        passAsFile = [ "xml" ];
      } (pkgs.writers.writePython3 "xml2json" {
        libraries = with python3.pkgs; [ python ];
      } ''
        import os
        import json
        from collections import ChainMap
        from xml.etree import ElementTree
        

        def xml_to_dict_recursive(root):
            all_descendants = list(root)
            if len(all_descendants) == 0:
                return {root.tag: root.text}
            else:
                merged_dict = ChainMap(*map(xml_to_dict_recursive, all_descendants))
                return {root.tag: dict(merged_dict)}


        with open(os.environ["xmlPath"]) as f:
            root = ElementTree.XML(f.read())
            xml = xml_to_dict_recursive(root)
            j = json.dumps(xml)

            with open(os.environ["out"], "w") as out:
                out.write(j)
      '')) {};
    in
      builtins.fromJSON (builtins.readFile xmlToJsonFile);

  renameAttrName = attrset: from: to:
    (lib.attrsets.filterAttrs (name: v: name == from) attrset) // {
      ${to} = attrset.${from};
    };

  # Taken from https://github.com/antifuchs/nix-flake-tests/blob/main/default.nix
  # with a nicer diff display function.
  check = { pkgs, tests }:
    let
      system = pkgs.stdenv.targetPlatform.system;
      formatValue = val:
        if (builtins.isList val || builtins.isAttrs val) then builtins.toJSON val
        else builtins.toString val;
      resultToString = { name, expected, result }:
        pkgs.callPackage (pkgs.runCommand "nix-flake-tests-error" {
          expected = formatValue expected;
          result = formatValue result;
          passAsFile = [ "expected" "result" ];
        } ''
          echo "${name} failed (- expected, + result)"
          cp ''${expectedPath} ''${expectedPath}.json
          cp ''${resultPath} ''${resultPath}.json
          ${pkgs.deepdiff}/bin/deep diff ''${expectedPath}.json ''${resultPath}.json
        '') {};



      #   ''
      #   ${name} failed: expected ${formatValue expected}, but got ${
      #     formatValue result
      #   }
      # '';
      results = pkgs.lib.runTests tests;
    in
    if results != [ ] then
      builtins.throw (builtins.concatStringsSep "\n" (map resultToString results))
    ## TODO: The derivation below is preferable but "nix flake check" hangs with it:
    ##       (it's preferable because "examples/many-failures" would then show all errors.)
    # pkgs.runCommand "nix-flake-tests-failure" { } ''
    #   cat <<EOF
    #   ${builtins.concatStringsSep "\n" (map resultToString results)}
    #   EOF
    #   exit 1
    # ''
    else
      pkgs.runCommand "nix-flake-tests-success" { } "echo > $out";

}
