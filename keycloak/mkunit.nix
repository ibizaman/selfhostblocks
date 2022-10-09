{ KeycloakService
}:
{ name
, configDir
, configFile
, user
, group
, dbPasswordFile
, postgresServiceName
, initialAdminFile ? null

, dependsOn ? {}
}:
{
  inherit name configDir configFile;

  pkg = KeycloakService {
    inherit configDir configFile;
    inherit user group;
    inherit dbPasswordFile initialAdminFile;
    inherit postgresServiceName;
  };

  inherit dependsOn;
  type = "systemd-unit";
}
