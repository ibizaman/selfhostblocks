# Run tests with nix-build -A tests.integration.keycloak
{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
}:

let
  pkgs = import nixpkgs {};

  version = "1.0";

  disnixos = pkgs.callPackage ./common.nix { inherit nixpkgs; };
in

rec {
  tarball = disnixos.sourceTarball {
    name = "testproject-zip";
    inherit version;
    src = ../../.;
    officialRelease = false;
  };
  
  builds = {
    simple = disnixos.genBuilds systems {
      name = "test-project-manifest";
      inherit version;
      inherit tarball;
      servicesFile = "tests/integration/keycloak/services.nix";
      networkFile = "tests/integration/keycloak/network.nix";
      distributionFile = "tests/integration/keycloak/distribution.nix";
    };
  };

  tests = {
    simple = disnixos.disnixTest builtins.currentSystem builds.simple {
      name = "test-project-test";
      inherit tarball;
      networkFile = "tests/integration/keycloak/network.nix";
      # dysnomiaStateDir = /var/state/dysnomia;
      testScript =
        ''
        def assert_service_started(machine, name):
            code, log = machine.systemctl("status " + name)
            if code != 0:
                raise Exception(name + " could not be started:\n---\n" + log + "---\n")

        def assert_database_exists(machine, name):
            if machine.succeed("""psql -XtA -U postgres -h localhost -c "SELECT 1 FROM pg_database WHERE datname='{}'" """.format(name)) != '1\n':
                raise Exception("could not find database '{}' in postgresql".format(name))

        with subtest("check postgres service started"):
            assert_service_started(test1, "postgresql.service")

        with subtest("check db is created"):
            assert_database_exists(test1, "keycloak")
        '';
    };
  };
}.tests
