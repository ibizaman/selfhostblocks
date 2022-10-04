{ TtrssUpdateService
}:
{ name
, user
, group
, documentRoot
, readOnlyPaths
, readWritePaths
, postgresServiceName
, dependsOn ? {}
}:

{
  inherit name;
  pkg = TtrssUpdateService {
    inherit documentRoot;
    inherit user group;

    inherit readOnlyPaths readWritePaths;
    inherit postgresServiceName;
  };

  inherit dependsOn;
  type = "systemd-unit";
}
