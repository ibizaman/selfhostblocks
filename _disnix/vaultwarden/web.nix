{ stdenv
, pkgs
, utils
}:
{ name
, path
}:

{
  inherit name;

  inherit path;

  pkg = stdenv.mkDerivation rec {
    inherit name;

    buildCommand =
      let
        dir = dirOf path;
        base = baseNameOf path;
      in ''
        mkdir -p $out
        ln -s ${pkgs.vaultwarden-vault}/share/vaultwarden/vault $out/${base}

        echo "${dir}" > $out/.dysnomia-targetdir

        cat > $out/.dysnomia-fileset <<FILESET
          symlink $out/${base}
          target .
        FILESET
      '';
  };

  type = "fileset";
}
