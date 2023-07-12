{ CaddySiteConfig
}:
{ CaddyConfig
, CaddyService
, name
, port
, siteName
, siteRoot
, phpFpmSiteSocket ? ""
}:
rec {
  inherit name;
  caddySocket = "${CaddyService.runtimeDirectory}/${siteName}.sock";
  pkg = CaddySiteConfig rec {
    inherit (CaddyConfig) siteConfigDir;
    inherit phpFpmSiteSocket;

    portBinding = port;
    bindService = siteName;
    siteSocket = caddySocket;
    serviceRoot = siteRoot;
  };
  type = "fileset";
}
