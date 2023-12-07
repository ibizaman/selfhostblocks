# Taken nearly verbatim from https://github.com/nix-community/home-manager/pull/4673
{ pkgs
, buildPackages
, lib
, nmdsrc
, stdenv
, documentation-highlighter
, nixos-render-docs

, release
, allModules
}:

let
  shbPath = toString ./..;

  gitHubDeclaration = user: repo: subpath:
    let urlRef = "main";
        end = if subpath == "" then "" else "/" + subpath;
    in {
      url = "https://github.com/${user}/${repo}/blob/${urlRef}${end}";
      name = "<${repo}${end}>";
    };

  ghRoot = (gitHubDeclaration "ibizaman" "selfhostblocks" "").url;

  buildOptionsDocs = args@{ modules, includeModuleSystemOptions ? true, ... }:
    let options = (lib.evalModules { inherit modules; }).options;
    in buildPackages.nixosOptionsDoc ({
      options = if includeModuleSystemOptions then
        options
                else
                  builtins.removeAttrs options [ "_module" ];
      transformOptions = opt:
        opt // {
          # Clean up declaration sites to not refer to the Home Manager
          # source tree.
          declarations = map (decl:
            gitHubDeclaration "ibizaman" "selfhostblocks"
              (lib.removePrefix "/" (lib.removePrefix shbPath (toString decl)))) opt.declarations;
        };
    } // builtins.removeAttrs args [ "modules" "includeModuleSystemOptions" ]);

  scrubbedModule = {
    _module.args.pkgs = lib.mkForce (nmd.scrubDerivations "pkgs" pkgs);
    _module.check = false;
  };

  optionsDocs = buildOptionsDocs {
    modules = allModules ++ [ scrubbedModule ];
    variablelistId = "selfhostblocks-options";
    includeModuleSystemOptions = false;
  };

  nmd = import nmdsrc {
    inherit lib;
    # The DocBook output of `nixos-render-docs` doesn't have the change
    # `nmd` uses to work around the broken stylesheets in
    # `docbook-xsl-ns`, so we restore the patched version here.
    pkgs = pkgs // {
      docbook-xsl-ns =
        pkgs.docbook-xsl-ns.override { withManOptDedupPatch = true; };
    };
  };

  outputPath = "share/doc/selfhostblocks";

  manpage-urls = pkgs.writeText "manpage-urls.json" ''{}'';
in stdenv.mkDerivation {
  name = "self-host-blocks-manual";

  nativeBuildInputs = [ nixos-render-docs ];

  src = ./.;

  buildPhase = ''
    mkdir -p out/media
    mkdir -p out/highlightjs
    mkdir -p out/static

    cp -t out/highlightjs \
      ${documentation-highlighter}/highlight.pack.js \
      ${documentation-highlighter}/LICENSE \
      ${documentation-highlighter}/mono-blue.css \
      ${documentation-highlighter}/loader.js

    cp -t out/static \
      ${nmdsrc}/static/style.css \
      ${nmdsrc}/static/highlightjs/tomorrow-night.min.css \
      ${nmdsrc}/static/highlightjs/highlight.min.js \
      ${nmdsrc}/static/highlightjs/highlight.load.js

    substituteInPlace ./options.md \
      --replace \
        '@OPTIONS_JSON@' \
        ${optionsDocs.optionsJSON}/share/doc/nixos/options.json

    find . -name "*.md" -print0 | \
      while IFS= read -r -d ''' f; do
        substituteInPlace "''${f}" \
          --replace \
            '@REPO@' \
            "${ghRoot}"
      done

    nixos-render-docs manual html \
      --manpage-urls ${manpage-urls} \
      --media-dir media \
      --revision ${lib.trivial.revisionWithDefault release} \
      --stylesheet static/style.css \
      --stylesheet static/tomorrow-night.min.css \
      --script static/highlight.min.js \
      --script static/highlight.load.js \
      --toc-depth 1 \
      --section-toc-depth 1 \
      manual.md \
      out/index.html
  '';

  installPhase = ''
    dest="$out/${outputPath}"
    mkdir -p "$(dirname "$dest")"
    mv out "$dest"
    mkdir -p $out/nix-support/
    echo "doc manual $dest index.html" >> $out/nix-support/hydra-build-products
  '';
}
