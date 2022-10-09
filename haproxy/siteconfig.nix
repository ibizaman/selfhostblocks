{ stdenv
, pkgs
, lib
}:
{ serviceName
, serviceAddress ? null
, serviceSocket ? null
, phpFastcgi ? false
, phpDocroot ? null
, phpIndex ? "index.php"
, extraUseBackendConditions ? {}
, extraFrontendOptions ? []
, extraBackendOptions ? []
}:

assert lib.assertMsg (
  (serviceAddress == null && serviceSocket != null)
  || (serviceAddress != null && serviceSocket == null)
) "set either serviceAddress or serviceSocket";

let
  backendOptions = lib.concatMapStrings (x : "\n  " + x) extraBackendOptions;

  serviceBind = if serviceAddress != null then serviceAddress else serviceSocket;

  backend =
    if !phpFastcgi
    then ''
    backend ${serviceName}
      mode http
      option forwardfor${backendOptions}
      server ${serviceName}1 ${serviceBind}
    '' else ''
    backend ${serviceName}
      mode http
      option forwardfor${backendOptions}
      use-fcgi-app ${serviceName}-php-fpm
      server ${serviceName}1 ${serviceBind} proto fcgi

    fcgi-app ${serviceName}-php-fpm
      log-stderr global
      docroot ${phpDocroot}
      index ${phpIndex}
      path-info ^(/.+\.php)(/.*)?$
    '';

  extraAclsCondition = lib.concatStrings (lib.attrsets.mapAttrsToList (k: v: "\nacl acl_${serviceName}_${k} ${v}") extraUseBackendConditions);

  extraAclsOr = lib.concatStrings (lib.attrsets.mapAttrsToList (k: v: " OR acl_${serviceName}_${k}") extraUseBackendConditions); 
in
{
  frontend = ''
  acl acl_${serviceName} hdr_beg(host) ${serviceName}.${extraAclsCondition}
  ''
  + lib.concatMapStrings (x: x + "\n") extraFrontendOptions
  + ''
  use_backend ${serviceName} if acl_${serviceName}${extraAclsOr}
  '';

  inherit backend;
}
