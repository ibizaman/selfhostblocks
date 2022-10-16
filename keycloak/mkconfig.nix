{ KeycloakConfig
}:
{ name
, configDir ? "/etc/keycloak"
, configFile ? "keycloak.conf"
, logLevel ? "INFO"
, metricsEnabled ? false
, hostname ? "keycloak.hostname.com"

, dbType ? "postgres"
, dbUsername ? "keycloak"
, dbHost ? x: "localhost"
, dbPort ? "5432"
, dbDatabase ? "keycloak"

, dependsOn ? {}
}:

{
  inherit name configDir configFile;

  inherit hostname;

  pkg = KeycloakConfig {
    inherit configDir configFile hostname;
    inherit logLevel metricsEnabled;
    inherit dbType dbUsername dbHost dbPort dbDatabase;
  };

  inherit dependsOn;
  type = "fileset";
}
