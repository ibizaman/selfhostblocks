{ KeycloakService
}:
{ name
, configDir
, configFile
, user
, group
, dbPasswordFile
, postgresServiceName
, initialAdminUsername ? "admin"
, initialAdminFile ? null

, dependsOn ? {}
}:
{
  inherit name configDir configFile;

  inherit initialAdminUsername;

  pkg = KeycloakService {
    inherit configDir configFile;
    inherit user group;
    inherit dbPasswordFile initialAdminUsername initialAdminFile;
    inherit postgresServiceName;
  };

  inherit dependsOn;
  type = "systemd-unit";
}
