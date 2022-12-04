{ KeycloakService
}:
{ name
, configDir
, configFile
, user
, group
, postgresServiceName
, initialAdminUsername ? "admin"
, keys

, dependsOn ? {}
}:
{
  inherit name configDir configFile;

  inherit initialAdminUsername;

  pkg = KeycloakService {
    inherit configDir configFile;
    inherit user group;
    inherit keys initialAdminUsername;
    inherit postgresServiceName;
  };

  inherit dependsOn;
  type = "systemd-unit";
}
