{ lib, ... }:
{
  config = {
    shb.restic.databases."<name>".settings = {
      repository = "";
    };
  };
}
