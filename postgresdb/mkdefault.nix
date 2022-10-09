{ PostgresDB
}:
{ name
, database
, username
, password ? null
, passwordFile ? null
, dependsOn ? {}
}:

{
  inherit name;
  inherit database username password passwordFile;

  pkg = PostgresDB {
    postgresDatabase = database;
    postgresUsername = username;
    postgresPassword = password;
    postgresPasswordFile = passwordFile;
  };

  inherit dependsOn;
  type = "postgresql-database";
}
