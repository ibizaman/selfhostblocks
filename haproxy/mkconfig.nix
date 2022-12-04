{ HaproxyConfig
}:
{ name
, configDir
, configFile
, config
, dependsOn ? {}
}:
{
  inherit name configDir configFile;
  inherit (config) user group;
  pkg = HaproxyConfig {
    inherit configDir configFile;
    inherit config;
  };

  inherit dependsOn;
  type = "fileset";
}
