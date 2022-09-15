{ PHPFPMSiteConfig
}:
{ PHPFPMConfig
, PHPFPMService
, name
, phpConfigDir
, siteName
, siteRoot
, socketUser
, socketGroup
, dependsOn
}:
rec {
  inherit name dependsOn;
  siteSocket = "/run/php-fpm/${siteName}.sock";
  pkg = PHPFPMSiteConfig {
    inherit (PHPFPMConfig) siteConfigDir;
    inherit (PHPFPMService) user group;
    inherit siteSocket phpConfigDir socketUser socketGroup;

    service = siteName;
    serviceRoot = siteRoot;
    allowedClients = "127.0.0.1";
  };
  type = "fileset";
}
