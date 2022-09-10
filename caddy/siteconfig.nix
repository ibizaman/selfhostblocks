{ stdenv
, pkgs
, utils
}:
{ siteConfigDir
, portBinding
, bindService
, serviceRoot ? "/usr/share/webapps/${bindService}"
, siteSocket ? null
, phpFpmSiteSocket ? null
, logLevel ? "WARN"
}:

let
  content =
    [
      "root * ${serviceRoot}"
      "file_server"
    ]
    ++ (
      if siteSocket != ""
      then [
        "bind unix/${siteSocket}"
      ]
      else []
    )
    ++ (
      if phpFpmSiteSocket != ""
      then [
        "php_fastcgi unix/${phpFpmSiteSocket}"
      ]
      else []
    );
in

utils.mkConfigFile {
  name = "${bindService}.config";
  dir = siteConfigDir;
  content = ''
    :${builtins.toString portBinding} {
      ${builtins.concatStringsSep "\n  " content}

      log {
        output stderr
        level ${logLevel}
      }
    }
  '';
} 
