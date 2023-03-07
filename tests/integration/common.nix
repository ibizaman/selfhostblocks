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
in
{
  disnixTest = system:
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
}
