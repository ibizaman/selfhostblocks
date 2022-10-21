{ stdenv
, pkgs
, lib
}:
{ serviceName
, servers ? []
, httpcheck ? null
, balance ? null
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
      concatStringsSep " " (
        [
          "server ${serviceName}${toString i} ${s.address}"
        ]
        ++ proto
        ++ (optional (hasAttr "check" s && s.check != null) (
          concatStrings (["check"] ++ (map (k: if !hasAttr k s.check then "" else " ${k} ${getAttr k s.check}") ["inter" "downinter" "fall" "rise"]))
        ))
      );

  serverslines = imap1 mkServer servers;

  backend =
    (
      concatStringsSep "\n" (
        [
          "backend ${serviceName}"
        ]
        ++ indent (
          [
            "mode http"
            "option forwardfor"
          ]
          ++ extraBackendOptions
          ++ optional (balance != null) "balance ${balance}"
          ++ optional (httpcheck != null) "option httpchk ${httpcheck}"
          ++ optional phpFastcgi "use-fcgi-app ${serviceName}-php-fpm"
          ++ serverslines
        )
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
