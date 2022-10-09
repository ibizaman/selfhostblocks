{ HaproxyConfig
}:
{ name
, configDir
, configFile
, user
, group
, statsEnable ? false
, statsPort ? null
, prometheusStatsUri ? null
, certPath ? null
, frontends ? []
, backends ? []
, dependsOn ? {}
}:
{
  inherit name configDir configFile;
  inherit user group;
  pkg = HaproxyConfig {
    inherit configDir configFile;
    inherit user group;
    inherit statsEnable statsPort;
    inherit prometheusStatsUri;
    inherit certPath;

    inherit frontends backends;
  };

  inherit dependsOn;
  type = "fileset";
}
