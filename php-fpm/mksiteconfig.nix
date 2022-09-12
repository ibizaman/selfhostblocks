{ PHPFPMSiteConfig
}:
{ PHPFPMConfig
, PHPFPMService
, name
, siteName
, siteRoot
, socketUser
, socketGroup
}:
rec {
  inherit name;
  siteSocket = "/run/php-fpm/${name}.sock";
  pkg = PHPFPMSiteConfig {
    inherit (PHPFPMConfig) siteConfigDir;
    inherit (PHPFPMService) user group;
    inherit siteSocket socketUser socketGroup;

    service = siteName;
    serviceRoot = siteRoot;
    allowedClients = "127.0.0.1";
  };
  type = "fileset";
}
