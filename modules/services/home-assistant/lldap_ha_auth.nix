{
  lib,
  pkgs,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  name = "lldap-ha-auth";

  src = pkgs.fetchFromGitHub {
    owner = "lldap";
    repo = "lldap";
    rev = "7d1f5abc137821c500de99c94f7579761fc949d8";
    sha256 = "sha256-8D+7ww70Ja6Qwdfa+7MpjAAHewtCWNf/tuTAExoUrg0=";
  };

  nativeBuildInputs = [
    pkgs.makeWrapper
  ];

  buildPhase = ''
    mkdir -p $out/bin

    cp example_configs/lldap-ha-auth.sh $out/bin/lldap-ha-auth
    chmod a+x $out/bin/lldap-ha-auth
  '';

  installPhase = ''
    wrapProgram $out/bin/lldap-ha-auth \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.gnused
          pkgs.curl
          pkgs.jq
        ]
      }
  '';
}
