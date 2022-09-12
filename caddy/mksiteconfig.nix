{ CaddySiteConfig
}:
{ CaddyConfig
, CaddyService
, name
, port
, siteName
, siteRoot
, siteSocket ? ""
}:
{
  inherit name;
  pkg = CaddySiteConfig rec {
    inherit (CaddyConfig) siteConfigDir;

    portBinding = port;
    bindService = siteName;
    siteSocket = "${CaddyService.runtimeDirectory}/${siteName}.sock";
    serviceRoot = siteRoot;
    phpFpmSiteSocket = siteSocket;
  };
  type = "fileset";
}
