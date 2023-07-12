{
  herculesCI = {...}: {
    onPush.default = {
      outputs = {...}: {
        unit = (import ./default.nix {}).tests.unit;
        integration = (import ./default.nix {}).tests.integration;
      };
    };
  };
}
