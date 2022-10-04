{ PHPFPMService
}:
{ name
, configDir
, configFile
, phpIniConfigDir
, phpIniConfigFile
, runtimeDirectory
, serviceSuffix
, dependsOn ? {}
}:

{
  inherit name configDir configFile;
  inherit phpIniConfigDir phpIniConfigFile;
  inherit runtimeDirectory;

  pkg = PHPFPMService {
    inherit serviceSuffix;
    configFile = "${configDir}/${configFile}";
    phpIni = "${phpIniConfigDir}/${phpIniConfigFile}";
  };

  inherit dependsOn;
  type = "systemd-unit";
}
