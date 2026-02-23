{ lib, shb }:
let
  sort =
    attr: vs:
    map (v: { ${v.name} = v.${attr}; }) (
      lib.sortOn (v: v.sortOrder) (lib.mapAttrsToList (n: v: v // { name = n; }) vs)
    );

  slufigy = builtins.replaceStrings [ "-" ] [ "_" ];

  mkService =
    groupName: serviceName:
    {
      request,
      ...
    }:
    apiKey: settings:
    lib.recursiveUpdate (
      {
        href = request.externalUrl;
        siteMonitor = if (request.internalUrl == null) then null else request.internalUrl;
        icon = "sh-${lib.toLower serviceName}";
      }
      // lib.optionalAttrs (apiKey != null) {
        widget = {
          # Duplicating because widgets call the api key various names
          # and duplicating is a hacky but easy solution.
          key = "{{HOMEPAGE_FILE_${slufigy groupName}_${slufigy serviceName}}}";
          password = "{{HOMEPAGE_FILE_${slufigy groupName}_${slufigy serviceName}}}";
          type = lib.toLower serviceName;
          url = if (request.internalUrl != null) then request.internalUrl else request.externalUrl;
        };
      }
    ) settings;

  asServiceGroup =
    cfg:
    sort "services" (
      lib.mapAttrs (
        groupName: groupCfg:
        shb.update "services" (
          services:
          sort "dashboard" (
            lib.mapAttrs (
              serviceName: serviceCfg:
              shb.update "dashboard" (
                dashboard:
                (mkService groupName serviceName) dashboard serviceCfg.apiKey (serviceCfg.settings or { })
              ) serviceCfg
            ) services
          )
        ) groupCfg
      ) cfg
    );

  allKeys =
    cfg:
    let
      flat = lib.flatten (
        lib.mapAttrsToList (
          groupName: groupCfg:
          lib.mapAttrsToList (
            serviceName: serviceCfg:
            lib.optionalAttrs (serviceCfg.apiKey != null) {
              inherit serviceName groupName;
              inherit (serviceCfg.apiKey.result) path;
            }
          ) groupCfg.services
        ) cfg
      );

      flatWithApiKey = builtins.filter (v: v != { }) flat;
    in
    builtins.listToAttrs (
      map (
        {
          groupName,
          serviceName,
          path,
        }:
        lib.nameValuePair "${slufigy groupName}_${slufigy serviceName}" path
      ) flatWithApiKey
    );
in
{
  inherit
    allKeys
    asServiceGroup
    mkService
    sort
    ;
}
