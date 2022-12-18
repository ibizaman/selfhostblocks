{ HaproxyConfig
}:
{ name
, configDir
, configFile
, user
, group
, config
, dependsOn ? {}
}:
{
  inherit name configDir configFile;
  inherit user group;

  pkg = HaproxyConfig {
    inherit configDir configFile;
    inherit config;
    inherit user group;
  };

  inherit dependsOn;
  type = "fileset";
}
