# Integration Tests

Integration tests configure real virtual machines and run tests on
those to assert some properties.

You can find all integration tests under the [tests/integration](/tests/integration) directory.

## Run integration tests

```console
nix-build -A tests.integration.keycloak
```
