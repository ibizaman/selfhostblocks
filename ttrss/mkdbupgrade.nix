{ TtrssUpgradeDBService
}:
{ name
, user
, binDir
, dependsOn ? {}
}:

{
  inherit name;
  pkg = TtrssUpgradeDBService {
    inherit user binDir;
  };

  inherit dependsOn;
  type = "wrapper";
}
