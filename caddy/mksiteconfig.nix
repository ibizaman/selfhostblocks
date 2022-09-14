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
rec {
  inherit name;
  caddySocket = "${CaddyService.runtimeDirectory}/${siteName}.sock";
  pkg = CaddySiteConfig rec {
    inherit (CaddyConfig) siteConfigDir;

    portBinding = port;
    bindService = siteName;
    siteSocket = caddySocket;
    serviceRoot = siteRoot;
    phpFpmSiteSocket = siteSocket;
  };
  type = "fileset";
}
