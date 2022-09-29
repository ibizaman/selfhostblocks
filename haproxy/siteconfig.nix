{ stdenv
, pkgs
}:
{ serviceName
, serviceSocket
, phpFastcgi ? false
, phpDocroot ? null
, phpIndex ? "index.php"
}:

let
  backend =
    if !phpFastcgi
    then ''
    backend ${serviceName}
      mode http
      option forwardfor
      server ${serviceName}1 ${serviceSocket}
    '' else ''
    backend ${serviceName}
      mode http
      option forwardfor
      use-fcgi-app ${serviceName}-php-fpm
      server ${serviceName}1 ${serviceSocket} proto fcgi

    fcgi-app ${serviceName}-php-fpm
      log-stderr global
      docroot ${phpDocroot}
      index ${phpIndex}
      path-info ^(/.+\.php)(/.*)?$
    '';
in
{
  acl = ''
  acl acl_${serviceName} hdr_beg(host) ${serviceName}.
  use_backend ${serviceName} if acl_${serviceName}
  '';

  inherit backend;
}
