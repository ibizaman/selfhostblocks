{ PostgresDB
}:
{ name
, username
, password
, database
, dependsOn ? {}
}:

{
  inherit name;
  pkg = PostgresDB {
    postgresUsername = username;
    postgresPassword = password;
    postgresDatabase = database;
  };

  inherit dependsOn;
  type = "postgresql-database";
}
