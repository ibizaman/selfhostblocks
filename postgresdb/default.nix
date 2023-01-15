{ stdenv
, pkgs
, lib
}:
{ name

, database
, username
, password ? null
, passwordFile ? null

, dependsOn ? {}
}:

assert lib.assertMsg (
  (password == null && passwordFile != null)
  || (password != null && passwordFile == null)
) "set either postgresPassword or postgresPasswordFile";

# From https://github.com/svanderburg/dysnomia/blob/master/dysnomia-modules/postgresql-database.in
# and https://github.com/svanderburg/dysnomia/blob/master/tests/deployment/postgresql-database.nix
#
# On activation, an initial dump can be restored. If the mutable component
# contains a sub folder named postgresql-databases/, then the dump files stored
# inside get imported.

# TODO: https://stackoverflow.com/a/69480184/1013628
{
  inherit name;
  inherit database username password passwordFile;

  pkg = stdenv.mkDerivation {
    name = database;

    src = pkgs.writeTextDir "${database}.sql" ''
      CREATE USER "${username}" WITH PASSWORD '${password}';
      GRANT ALL PRIVILEGES ON DATABASE "${username}" TO "${database}";
    '';

    buildCommand = ''
      mkdir -p $out/postgresql-databases
      cp $src/*.sql $out/postgresql-databases
    '';
  };

  inherit dependsOn;
  type = "postgresql-database";
}
