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
      # extraParams = {
      #   "extra-builtins-file" = ../../extra-builtins.nix;
      # };
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
        # Wait until the front-end application is deployed
        # $test1->waitForFile("/var/tomcat/webapps/testapp");

        # Wait a little longer and capture the output of the entry page
        # my $result = $test1->mustSucceed("sleep 10; curl --fail http://test2:8080/testapp");
        '';
    };
  };
}.tests

# let
#   utils = import ../../utils.nix {
#     inherit pkgs;
#     inherit (pkgs) stdenv lib;
#   };
#   keycloak = import ../../keycloak/unit.nix {
#     inherit pkgs utils;
#     inherit (pkgs) stdenv lib;
#   };
# in
# makeTest {
#   nodes = {
#     machine = {config, pkgs, ...}:
#     {
#       virtualisation.memorySize = 1024;
#       virtualisation.diskSize = 4096;

#       environment.systemPackages = [ dysnomia pkgs.curl ];
#     };
#   };
#   testScript = ''
#     def check_keycloak_activated():
#         machine.succeed("sleep 5")
#         machine.succeed("curl --fail http://keycloak.test.tiserbox.com")

#     def check_keycloak_deactivated():
#         machine.succeed("sleep 5")
#         machine.fail("curl --fail http://keycloak.test.tiserbox.com")

#     start_all()

#     # Test the keycloak module. Start keycloak and see if we can query the endpoint.
#     machine.succeed(
#         "dysnomia --type docker-container --operation activate --component ${keycloak} --environment"
#     )
#     check_keycloak_activated()

#     # Deactivate keycloak. Check if it is not running anymore
#     machine.succeed(
#         "dysnomia --type docker-container --operation deactivate --component ${keycloak} --environment"
#     )
#     check_keycloak_deactivated()
#   '';
# }
