{ HaproxyService
}:
{ name
, configDir
, configFile
, dependsOn ? {}
}:

{
  inherit name configDir configFile;
  pkg = HaproxyService {
    inherit configDir configFile;
  };

  inherit dependsOn;
  type = "systemd-unit";
}
