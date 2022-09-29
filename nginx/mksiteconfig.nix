{ NginxSiteConfig
}:
{ siteConfigDir
, runtimeDirectory
, name
, port
, siteName
, siteRoot
, phpFpmSiteSocket ? ""
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
  type = "fileset";
}
