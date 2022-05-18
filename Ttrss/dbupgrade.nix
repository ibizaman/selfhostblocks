{ stdenv
, pkgs
}:
{ binDir
, user
}:
{ TtrssPostgresDB
, TtrssService
}:

stdenv.mkDerivation {
  name = "dbupgrade";

  src = pkgs.writeTextDir "wrapper" ''
  #!/bin/bash -e

  sudo -u ${user} bash <<HERE
  case "$1" in
    activate)
      ${pkgs.php}/bin/php ${binDir}/update.php --update-schema=force-yes
      ;;
    lock)
        if [ -f /tmp/wrapper.lock ]
        then
            exit 1
        else
            echo "1" > /tmp/wrapper.lock
        fi
        ;;
    unlock)
        rm -f /tmp/wrapper.lock
        ;;
  esac
  HERE
  '';

  installPhase = ''
  mkdir -p $out/bin
  cp $src/wrapper $out/bin
  chmod +x $out/bin/*
  '';
}
