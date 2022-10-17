{ stdenv
, pkgs
, lib
}:
{ serviceName
, servers ? []
, phpFastcgi ? false
, phpDocroot ? null
, phpIndex ? "index.php"
, extraUseBackendConditions ? {}
, extraFrontendOptions ? []
, extraBackendOptions ? []
}:

with lib;
with lib.lists;
with lib.attrsets;
let
  indent = map (x: "  " + x);

  mkServer = i: s:
    let
      proto = optional phpFastcgi "proto fcgi";
    in
    concatStringsSep " " ([
      "server ${serviceName}${toString i} ${s.address}"
    ] ++ proto ++ s.extra);

  serverslines = imap1 mkServer servers;

  backend =
    (
      concatStringsSep "\n" (
        [
          "backend ${serviceName}"
        ]
        ++ indent [
          "mode http"
          "option forwardfor"
        ]
        ++ indent extraBackendOptions
        ++ optional phpFastcgi "  use-fcgi-app ${serviceName}-php-fpm"
        ++ indent serverslines
        ++ [""]) # final newline
    ) +
    (if !phpFastcgi then "" else ''

    fcgi-app ${serviceName}-php-fpm
      log-stderr global
      docroot ${phpDocroot}
      index ${phpIndex}
      path-info ^(/.+\.php)(/.*)?$
    '');

  extraAclsCondition = concatStrings (mapAttrsToList (k: v: "\nacl acl_${serviceName}_${k} ${v}") extraUseBackendConditions);

  extraAclsOr = concatStrings (mapAttrsToList (k: v: " OR acl_${serviceName}_${k}") extraUseBackendConditions);
in
{
  frontend = ''
  acl acl_${serviceName} hdr_beg(host) ${serviceName}.${extraAclsCondition}
  ''
  + concatMapStrings (x: x + "\n") extraFrontendOptions
  + ''
  use_backend ${serviceName} if acl_${serviceName}${extraAclsOr}
  '';

  inherit backend;
}
