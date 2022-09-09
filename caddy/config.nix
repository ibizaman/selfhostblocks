{ stdenv
, pkgs
, utils
}:
{ configDir ? "/etc/caddy"
, configFile ? "Caddyfile"
, siteConfigDir
}:

utils.mkConfigFile {
  name = configFile;
  dir = configDir;
  content = ''
    {
      # Disable auto https
      http_port 10001
      https_port 10002
    }
    
    import ${siteConfigDir}/*
  '';
} 
