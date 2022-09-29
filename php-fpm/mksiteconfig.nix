{ PHPFPMSiteConfig
}:
{ PHPFPMConfig
, user
, group
, name
, phpConfigDir
, siteName
, siteRoot
, siteSocket
, socketUser
, socketGroup
, dependsOn
, connectsTo
}:
rec {
  inherit name user group siteSocket;
  inherit dependsOn connectsTo;

  pkg = PHPFPMSiteConfig {
    inherit (PHPFPMConfig) siteConfigDir;
    inherit user group;
    inherit siteSocket phpConfigDir socketUser socketGroup;

    service = siteName;
    serviceRoot = siteRoot;
    allowedClients = "127.0.0.1";
  };
  type = "fileset";
}
