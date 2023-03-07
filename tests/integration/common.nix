{ nixpkgs, pkgs }:
let
  generateManifestSrc =
    {name, tarball}:

    pkgs.stdenv.mkDerivation {
      name = "${name}-manifest-src";
      buildCommand =
        ''
          mkdir -p $out
          cd $out
          tar xfvj ${tarball}/tarballs/*.tar.bz2 --strip-components=1
        '';
    };

  disnixos = import "${pkgs.disnixos}/share/disnixos/testing.nix" {
    inherit nixpkgs;
  };

  # We need this function because, for a reason that eludes me, the
  # one defined in disnixos fails the name attribute not correctly set
  # in the call to simpleTest. The only difference between this
  # function and the one in disnixos is the additional `inherit name`
  # line.
  customDisnixTest = system:
    {name, manifest, tarball, networkFile, externalNetworkFile ? false, testScript, dysnomiaStateDir ? "", postActivateTimeout ? 1}:

    let
      manifestSrc = generateManifestSrc {
        inherit name tarball;
      };

      network = if externalNetworkFile then import networkFile else import "${manifestSrc}/${networkFile}";
    in
      with import "${nixpkgs}/nixos/lib/testing-python.nix" { inherit system; };

    simpleTest {
      nodes = network;
      inherit name;

      testScript = import "${pkgs.disnixos}/share/disnixos/generate-testscript.nix" {
        inherit network testScript dysnomiaStateDir postActivateTimeout;
        inherit (pkgs) disnix daemon socat libxml2;
        inherit (pkgs.lib) concatMapStrings;
        manifestFile = "${manifest}/manifest.xml";
      };
    };
in
{
  inherit (disnixos) sourceTarball;

  genBuilds = systems: config:
    pkgs.lib.genAttrs systems (system:
      let
        pkgs = import nixpkgs { inherit system; };

        disnixos = import "${pkgs.disnixos}/share/disnixos/testing.nix" {
          inherit nixpkgs system;
        };
      in
        disnixos.buildManifest config
    );

  disnixTest = currentSystem: manifest: config:
    customDisnixTest currentSystem (config // {
      manifest = builtins.getAttr currentSystem manifest;
    });
}
