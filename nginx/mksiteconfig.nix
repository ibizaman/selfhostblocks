{ NginxSiteConfig
}:
{ siteConfigDir
, runtimeDirectory
, name
, port
, siteName
, siteRoot
, phpFpmSiteSocket ? ""
, dependsOn ? {}
}:
rec {
  inherit name siteConfigDir;
  siteConfigFile = "${siteName}.config";
  nginxSocket = "${runtimeDirectory}/${siteName}.sock";
  pkg = NginxSiteConfig rec {
    inherit siteConfigDir siteConfigFile;
    inherit phpFpmSiteSocket;

    portBinding = port;
    bindService = siteName;
    siteSocket = nginxSocket;
    serviceRoot = siteRoot;
  };

  inherit dependsOn;
  type = "fileset";
}
