{ PHPFPMConfig
}:
{ name
, configDir
, configFile
, siteConfigDir
, dependsOn ? {}
}:

{
  inherit name configDir configFile;
  inherit siteConfigDir;

  pkg = PHPFPMConfig {
    inherit configDir configFile siteConfigDir;
  };

  inherit dependsOn;
  type = "fileset";
}
