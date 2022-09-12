{ stdenv
, pkgs
, utils
}:
{ configDir ? "/etc/php"
, configFile ? "php-fpm.conf"
, siteConfigDir ? "${configFile}/conf.d"
, logLevel ? "notice"
}:

utils.mkConfigFile {
  name = configFile;
  dir = configDir;
  content = ''
  [global]
    error_log = syslog
    syslog.ident = php-fpm
    log_level = ${logLevel}
    include=${siteConfigDir}/*
  '';
}
