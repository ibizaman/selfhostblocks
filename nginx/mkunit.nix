{ NginxService
}:
{ name
, configDir
, configFile
, user
, group
, runtimeDirectory
, serviceSuffix
, dependsOn ? {}
}:
{
  inherit name configDir configFile;
  inherit user group;
  inherit runtimeDirectory;
  pkg = NginxService {
    inherit serviceSuffix;
    inherit user group;
    inherit configDir configFile;
  };

  inherit dependsOn;
  type = "systemd-unit";
}
