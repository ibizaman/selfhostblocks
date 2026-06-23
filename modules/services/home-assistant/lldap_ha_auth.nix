{
  lib,
  pkgs,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  name = "lldap-ha-auth";

  src = pkgs.fetchFromGitHub {
    owner = "ibizaman";
    repo = "lldap";
    rev = "adaf17c70336ec2562d23d1b9775579d62691b51";
    sha256 = "sha256-4FqfglEss5MlnxvjP40zbxqtwvB/GGMs7HwK9CBNBUQ=";
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
