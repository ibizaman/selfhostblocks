{ KeycloakCliService
}:
{ name
, configDir
, configFile

, keycloakServiceName
, keycloakSecretsDir
, keycloakAvailabilityTimeout ? "120s"
, keycloakUrl
, keycloakUser
, keys

, dependsOn ? {}
}:

{
  inherit name configDir configFile;
  pkg = KeycloakCliService {
    inherit configDir configFile;

    inherit keycloakServiceName;
    inherit keycloakSecretsDir
      keycloakAvailabilityTimeout
      keycloakUrl keycloakUser
      keys;
  };

  inherit dependsOn;
  type = "systemd-unit";
}
