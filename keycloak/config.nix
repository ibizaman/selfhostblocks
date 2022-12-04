{ stdenv
, pkgs
, lib
, utils
}:
{ configDir ? "/etc/keycloak"
, configFile ? "keycloak.conf"
, logLevel ? "INFO"
, metricsEnabled ? false
, hostname

, dbType ? "postgres"
, dbUsername ? "keycloak"
, dbHost ? x: "localhost"
, dbPort ? "5432"
, dbDatabase ? "keycloak"
}:
{ KeycloakPostgresDB
}:

assert lib.assertOneOf "dbType" dbType ["postgres"];

utils.mkConfigFile {
  name = configFile;
  dir = configDir;
  content = ''
  # The password of the database user is given by an environment variable.
  db=${dbType}
  db-username=${dbUsername}
  db-url-host=${dbHost {inherit KeycloakPostgresDB;}}
  db-url-port=${dbPort}
  db-url-database=${dbDatabase}
  # db-url-properties=  # Would be used for ssl, see https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/web-apps/keycloak.nix#L491
  
  # Observability
  
  # If the server should expose metrics and healthcheck endpoints.
  metrics-enabled=${if metricsEnabled then "true" else "false"}
  
  # HTTP
  
  # The file path to a server certificate or certificate chain in PEM format.
  #https-certificate-file=''${kc.home.dir}conf/server.crt.pem
  
  # The file path to a private key in PEM format.
  #https-certificate-key-file=''${kc.home.dir}conf/server.key.pem
  
  # The proxy address forwarding mode if the server is behind a reverse proxy.
  # https://www.keycloak.org/server/reverseproxy
  proxy=edge
  
  # Do not attach route to cookies and rely on the session affinity capabilities from reverse proxy
  #spi-sticky-session-encoder-infinispan-should-attach-route=false
  
  # Hostname for the Keycloak server.
  hostname=${hostname}
  
  spi-x509cert-lookup-provider=haproxy
  
  log-level=${logLevel}
  '';
}
