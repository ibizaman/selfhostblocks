{ PHPConfig
}:
{ name
, configDir
, configFile
, pkgExtraArguments ? {}
, dependsOn ? {}
}:
rec {
  inherit name configDir configFile;
  inherit dependsOn;

  pkg = PHPConfig ({
    inherit configDir configFile;
  } // pkgExtraArguments);

  type = "fileset";
}
