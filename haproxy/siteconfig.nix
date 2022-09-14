{ stdenv
, pkgs
}:
{ serviceName
, serviceSocket
}:

{
  acl = ''
  acl acl_${serviceName} hdr_beg(host) ${serviceName}.
  use_backend ${serviceName} if acl_${serviceName}
  '';

  backend = ''
  backend ${serviceName}
    mode http
    option forwardfor
    server ${serviceName}1 ${serviceSocket}
  '';
}
