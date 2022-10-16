{ KeycloakCliConfig
}:
{ name
, configDir ? "/etc/keycloak-cli-config"
, configFile ? "config.json"
, config ? ""
}:

{
  inherit name configDir configFile;

  pkg = KeycloakCliConfig {
    inherit configDir configFile;

    inherit config;
  };

  type = "fileset";
}
    
