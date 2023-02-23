{ nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem
}:

let
  pkgs = import nixpkgs {inherit system;};

  disnixos = import "${pkgs.disnixos}/share/disnixos/testing.nix" {
    inherit nixpkgs system;
  };

  version = "1.0";
in

rec {
  tarball = disnixos.sourceTarball {
    name = "testproject-zip";
    inherit version;
    src = ./.;
    officialRelease = false;
  };
  
  manifest = 
    disnixos.buildManifest {
      name = "test-project-manifest";
      version = builtins.readFile ./version;
      inherit tarball;
      servicesFile = "keycloak/services.nix";
      networkFile = "keycloak/network.nix";
      distributionFile = "keycloak/distribution.nix";
    };

  tests =
    disnixos.disnixTest {
      name = "test-project-tests";
      inherit tarball manifest;
      networkFile = "keycloak/network.nix";
      dysnomiaStateDir = /var/state/dysnomia;
      testScript =
        ''
          # Wait until the front-end application is deployed
          $test1->waitForFile("/var/tomcat/webapps/testapp");
           
          # Wait a little longer and capture the output of the entry page
          my $result = $test1->mustSucceed("sleep 10; curl --fail http://test2:8080/testapp");
        '';
    };
}

# let
#   utils = import ../../utils.nix {
#     inherit pkgs;
#     inherit (pkgs) stdenv lib;
#   };
#   keycloak = import ../../pkgs/keycloak/unit.nix {
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
