{ exec, ... }: {
  pass = name: exec [./nix-pass.sh name];
}
