{ KeycloakCliConfig
}:
{ name
, configDir ? "/etc/keycloak-cli-config"
, configFile ? "config.json"
, realm
, domain
, roles ? {}
, clients ? {}
, users ? {}
}:

{
  inherit name configDir configFile;

  pkg = KeycloakCliConfig {
    inherit configDir configFile;

    inherit realm domain roles clients users;
  };

  type = "fileset";
}
    
