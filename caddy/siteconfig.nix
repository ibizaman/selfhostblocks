{ stdenv
, pkgs
, utils
}:
{ siteConfigDir
, runtimeDirectory
, portBinding
, bindService
, useSocket ? false
, serviceRoot ? "/usr/share/webapps/${bindService}"
, phpFpmRuntimeDirectory ? "/run/php-fpm"
, phpFastcgi ? null
, logLevel ? "WARN"
}:

let
  content =
    [
      "root * ${serviceRoot}"
      "file_server"
    ]
    ++ (
      if useSocket
      then [
        "bind unix/${runtimeDirectory}/${bindService}.sock"
      ]
      else []
    )
    ++ (
      if phpFastcgi
      then [
        "php_fastcgi unix/${phpFpmRuntimeDirectory}/${bindService}.sock"
      ]
      else []
    );
in

utils.mkConfigFile {
  name = "${bindService}.config";
  dir = siteConfigDir;
  content = ''
    :${builtins.toString portBinding} {
      ${builtins.concatStringsSep "\n    " content}

      log {
          output stderr
          level ${logLevel}
      }
    }
  '';
} 
