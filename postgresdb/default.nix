{ stdenv, pkgs }:
{ postgresUsername
, postgresPassword
, postgresDatabase
}:

# From https://github.com/svanderburg/dysnomia/blob/master/dysnomia-modules/postgresql-database.in
# and https://github.com/svanderburg/dysnomia/blob/master/tests/deployment/postgresql-database.nix
#
# On activation, an initial dump can be restored. If the mutable component
# contains a sub folder named postgresql-databases/, then the dump files stored
# inside get imported.

stdenv.mkDerivation {
  name = postgresDatabase;

  src = pkgs.writeTextDir "${postgresDatabase}.sql" ''
    CREATE USER "${postgresUsername}" WITH PASSWORD '${postgresPassword}';
    GRANT ALL PRIVILEGES ON DATABASE "${postgresUsername}" TO "${postgresDatabase}";
  '';

  buildCommand = ''
    mkdir -p $out/postgresql-databases
    cp $src/*.sql $out/postgresql-databases
  '';
}
