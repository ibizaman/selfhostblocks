# SelfHostBlocks Service Implementation Guide {#service-implementation-guide}

This guide documents the complete process for implementing a new service in SelfHostBlocks, based on lessons learned from the nzbget implementation and analysis of existing service patterns.

**Note**: SelfHostBlocks aims to be "the smallest amount of code above what is available in nixpkgs" (see `docs/contributing.md`). Services should leverage existing nixpkgs options when possible and focus on providing contract integrations rather than reimplementing configuration.

## What Makes a "Complete" SHB Service {#complete-shb-service}

According to the project maintainer's criteria, a service is considered fully supported if it includes:

1. **SSL block integration** - HTTPS/TLS certificate management
2. **Backup block integration** - Automated backup of service data
3. **Monitoring integration** - Prometheus metrics and health checks
4. **LDAP (LLDAP) integration** - Directory-based authentication
5. **SSO (Authelia) integration** - Single sign-on authentication
6. **Comprehensive tests** - All integration variants tested

## Pre-Implementation Research {#pre-implementation-research}

### 1. Analyze Existing Services {#analyze-existing-services}

Before starting, study existing services to understand patterns:

```bash
# Study service patterns
ls modules/services/          # List all services
cat modules/services/deluge.nix   # Best practice example
cat modules/services/vaultwarden.nix  # Another good example
```

**Key patterns to identify:**
- Configuration structure and options
- How contracts are used (SSL, backup, monitoring, secrets)
- Authentication integration approaches
- Service-specific settings and defaults

### 2. Understand the Target Service {#understand-target-service}

Research the service you're implementing:
- **Configuration format** (YAML, INI, JSON, etc.)
- **Authentication methods** (built-in users, LDAP, OIDC/OAuth)
- **API endpoints** (for monitoring/health checks)
- **Data directories** (what needs backing up)
- **Network requirements** (ports, protocols)
- **Dependencies** (databases, external tools)

### 3. Check NixOS Integration {#check-nixos-integration}

Verify nixpkgs support:
```bash
# Check if NixOS service exists
nix eval --impure --expr '(import <nixpkgs/nixos> { configuration = {...}: {}; }).options.services' --apply 'builtins.attrNames' --json | jq -r '.[]' | grep -i servicename
# or search online: https://search.nixos.org/options?query=services.servicename
```

If no nixpkgs integration exists, you may need to:
- Package the service first
- Use containerized approach
- Request upstream nixpkgs integration

## Implementation Steps {#implementation-steps}

### 1. Create the Service Module {#create-service-module}

Location: `modules/services/servicename.nix`

**Basic structure:**
```nix
{ config, pkgs, lib, ... }:

let
  cfg = config.shb.servicename;
  contracts = pkgs.callPackage ../contracts {};
  shblib = pkgs.callPackage ../../lib {};
  fqdn = "${cfg.subdomain}.${cfg.domain}";
  
  # Choose appropriate format based on service config
  settingsFormat = pkgs.formats.yaml {};  # or .ini, .json, etc.
in
{
  options.shb.servicename = {
    # Core options (always required)
    enable = lib.mkEnableOption "selfhostblocks.servicename";
    subdomain = lib.mkOption { ... };
    domain = lib.mkOption { ... };
    
    # SSL integration (always include)
    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };
    
    # Service-specific options
    port = lib.mkOption { ... };
    dataDir = lib.mkOption { ... };
    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
        options = {
          # Define key options with descriptions
        };
      };
    };
    
    # Authentication options
    authEndpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "OIDC endpoint for SSO";
      default = null;
    };
    
    ldap = lib.mkOption { ... };  # LDAP integration
    users = lib.mkOption { ... }; # Local user management
    
    # Integration options
    backup = lib.mkOption {
      type = lib.types.submodule {
        options = contracts.backup.mkRequester {
          user = "servicename";
          sourceDirectories = [ cfg.dataDir ];
        };
      };
    };
    
    monitoring = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          # Service-specific monitoring options
        };
      });
      default = null;
    };
    
    # System options
    extraServiceConfig = lib.mkOption { ... };
    logLevel = lib.mkOption { ... };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Base service configuration
      services.servicename = {
        enable = true;
        # Map SHB options to nixpkgs service options
      };
      
      # Nginx reverse proxy
      shb.nginx.vhosts = [{
        inherit (cfg) subdomain domain ssl;
        upstream = "http://127.0.0.1:${toString cfg.port}";
        
        # SSO integration
        autheliaRules = lib.mkIf (cfg.authEndpoint != null) [
          {
            domain = fqdn;
            policy = "bypass";
            resources = [ "^/api" ];  # API endpoints
          }
          {
            domain = fqdn;
            policy = "two_factor";
            resources = [ "^.*" ];    # Everything else
          }
        ];
      }];
      
      # User/group setup
      users.users.servicename = {
        extraGroups = [ "media" ];  # If needed for file access
      };
      
      # Directory permissions
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 servicename servicename - -"
      ];
    }
    
    # Monitoring configuration (conditional)
    (lib.mkIf (cfg.monitoring != null) {
      services.prometheus.scrapeConfigs = [{
        job_name = "servicename";
        static_configs = [{
          targets = [ "127.0.0.1:${toString cfg.port}" ];
          labels = {
            hostname = config.networking.hostName;
            domain = cfg.domain;
          };
        }];
        metrics_path = "/metrics";  # or appropriate endpoint
        scrape_interval = "30s";
      }];
    })
  ]);
}
```

### 2. Key Implementation Considerations {#implementation-considerations}

#### Configuration Management {#configuration-management}
- **Use freeform settings** when possible: `freeformType = settingsFormat.type`
- **Provide sensible defaults** for common options
- **Use lib.mkDefault** for user-overridable settings
- **Use lib.mkForce** for security-critical settings

#### Authentication Integration {#authentication-integration}
- **SSO (Authelia)**: Use `autheliaRules` with appropriate bypass policies
- **LDAP**: Follow the patterns from existing services
- **Local users**: Use SHB secret contracts for password management

#### Security Best Practices {#security-best-practices}
- **Bind to localhost**: Services should listen on `127.0.0.1` only
- **Use nginx for TLS**: Don't configure TLS in the service itself
- **Proper file permissions**: Use systemd.tmpfiles.rules
- **Secret management**: Always use SHB secret contracts

### 3. Monitoring Implementation {#monitoring-implementation}

Choose the appropriate monitoring approach:

#### Option A: Native Prometheus Metrics {#native-prometheus-metrics}
If the service supports Prometheus natively:
```nix
services.prometheus.scrapeConfigs = [{
  job_name = "servicename";
  static_configs = [{ targets = [ "127.0.0.1:${toString cfg.port}" ]; }];
  metrics_path = "/metrics";
}];
```

#### Option B: API Health Check {#api-health-check}
If no native metrics, monitor API endpoints:
```nix
services.prometheus.scrapeConfigs = [{
  job_name = "servicename";
  static_configs = [{ targets = [ "127.0.0.1:${toString cfg.port}" ]; }];
  metrics_path = "/api/status";  # or appropriate endpoint
}];
```

#### Option C: External Exporter {#external-exporter}
For services requiring dedicated exporters (like Deluge):
```nix
services.prometheus.exporters.servicename = {
  enable = true;
  # exporter-specific configuration
};
```

### 4. Create Comprehensive Tests {#create-comprehensive-tests}

Location: `test/services/servicename.nix`

**Test structure:**
```nix
{ pkgs, ... }:
let
  testLib = pkgs.callPackage ../common.nix {};
  
  # Common test scripts
  commonTestScript = testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.servicename.ssl);
    waitForServices = { ... }: [ "nginx.service" "servicename.service" ];
    waitForPorts = { node, ... }: [ node.config.services.servicename.port ];
    
    # Service-specific connectivity test
    extraScript = { node, proto_fqdn, ... }: ''
      with subtest("service connectivity"):
          response = curl(client, "", "${proto_fqdn}/api/health")
          # Add service-specific checks
    '';
  };
  
  # Monitoring test script
  prometheusTestScript = { nodes, ... }: ''
    server.wait_for_open_port(${toString nodes.server.config.services.servicename.port})
    with subtest("prometheus monitoring"):
        # Test the actual monitoring endpoint
        response = server.succeed("curl -sSf http://localhost:${port}/metrics")
        # Validate response format
  '';
  
  # Base configuration
  basic = { config, ... }: {
    imports = [
      testLib.baseModule
      ../../modules/services/servicename.nix
    ];
    
    shb.servicename = {
      enable = true;
      inherit (config.test) domain subdomain;
      # Basic configuration
    };
  };
  
in {
  # Test variants (all 6 required)
  basic = lib.shb.runNixOSTest { ... };
  backup = lib.shb.runNixOSTest { ... };
  https = lib.shb.runNixOSTest { ... };
  ldap = lib.shb.runNixOSTest { ... };
  monitoring = lib.shb.runNixOSTest { ... };
  sso = lib.shb.runNixOSTest { ... };
}
```

#### Required Test Variants {#required-test-variants}

1. **basic**: Core functionality without authentication
2. **backup**: Tests backup integration
3. **https**: Tests SSL/TLS integration  
4. **ldap**: Tests LDAP authentication
5. **monitoring**: Tests Prometheus integration
6. **sso**: Tests Authelia SSO integration

### 5. Update Flake Configuration {#update-flake-configuration}

Add to `flake.nix`:

```nix
allModules = [
  # ... existing modules
  modules/services/servicename.nix
];
```

```nix
checks = {
  # ... existing checks
  // (vm_test "servicename" ./test/services/servicename.nix)
};
```

### 6. Create Service Documentation {#create-service-documentation}

Create comprehensive documentation for the new service:

**Location**: `modules/services/servicename/docs/default.md`

```markdown
# ServiceName Service {\#services-servicename}

Brief description of what the service does.

## Features {\#services-servicename-features}

- Feature 1
- Feature 2

## Usage {\#services-servicename-usage}

### Basic Configuration {\#services-servicename-basic}

shb.servicename = {
  enable = true;
  domain = "example.com";
  subdomain = "servicename";
};

### SSL Configuration {\#services-servicename-ssl}

shb.servicename.ssl.paths = {
  cert = /path/to/cert;
  key = /path/to/key;
};

## Options Reference {\#services-servicename-options}

{=include=} options
id-prefix: services-servicename-options-
list-id: selfhostblocks-servicename-options
source: @OPTIONS_JSON@
```

**Important**: Use consistent heading ID patterns:
- Service overview: `{\#services-servicename}`  
- Features: `{\#services-servicename-features}`
- Usage sections: `{\#services-servicename-basic}`, `{\#services-servicename-ssl}`, etc.
- Options: `{\#services-servicename-options}`

Note: Replace `servicename` with your actual service name (e.g., `nzbget`, `jellyfin`).

For the `@OPTIONS_JSON@` to work, a line must be added
in the `flake.nix` file:

```nix
packages.manualHtml = pkgs.callPackage ./docs {
  modules = {
    "blocks/authelia" = ./modules/blocks/authelia.nix;
    // Add line and keep in alphabetical order.
  };
};
```

### 7. Update Redirects Automatically {#update-redirects-automatically}

After creating documentation, generate the required redirects:

```bash
# Scan documentation and add missing redirects
nix run .#update-redirects

# Review the changes
git diff docs/redirects.json

# The tool will show what redirects were added
```

The automation will:
- Find all heading IDs in your documentation
- Generate appropriate redirect entries
- Add them to `docs/redirects.json`
- Follow established naming patterns

### 8. Handle Unfree Dependencies {#handle-unfree-dependencies}

If the service requires unfree packages:

```nix
# In flake.nix
config = {
  allowUnfree = true;
  permittedInsecurePackages = [
    # List any required insecure packages
  ];
};
```

Update CI workflow if needed:
```yaml
# In .github/workflows/build.yaml
- name: Setup Nix
  uses: cachix/install-nix-action@v31
  with:
    extra_nix_config: |
      allow-unfree = true
```

## Testing and Validation {#testing-and-validation}

### Local Testing {#local-testing}
```bash
# Test redirect automation
nix run .#update-redirects

# Test all service variants (replace ${system} with your system, e.g., x86_64-linux)
nix build .#checks.${system}.vm_servicename_basic
nix build .#checks.${system}.vm_servicename_backup
nix build .#checks.${system}.vm_servicename_https
nix build .#checks.${system}.vm_servicename_ldap
nix build .#checks.${system}.vm_servicename_monitoring
nix build .#checks.${system}.vm_servicename_sso

# Or run all tests (as recommended in docs/contributing.md)
nix flake check

# For interactive testing and debugging, see docs/contributing.md:
# nix run .#checks.${system}.vm_servicename_basic.driverInteractive

# Test documentation build (includes redirect validation)
nix build .#manualHtml
```

### Iterative Development Approach {#iterative-development-approach}

1. **Start with basic functionality** - get core service working
2. **Add SSL integration** - enable HTTPS
3. **Add backup integration** - ensure data protection
4. **Add monitoring** - implement health checks
5. **Add authentication** - LDAP and SSO integration
6. **Create documentation** - write service documentation with heading IDs
7. **Update redirects** - run `nix run .#update-redirects` to generate redirects
8. **Comprehensive testing** - all 6 test variants
9. **Final validation** - ensure documentation builds correctly

## Common Pitfalls and Solutions {#common-pitfalls-and-solutions}

### Configuration Issues {#configuration-issues}
- **Problem**: Service doesn't start due to config validation
- **Solution**: Use `lib.mkDefault` for user settings, `lib.mkForce` for security settings

### Authentication Integration {#authentication-integration-pitfalls}
- **Problem**: SSO redirect loops or access denied
- **Solution**: Check `autheliaRules` bypass patterns for API endpoints

### Monitoring Failures {#monitoring-failures}
- **Problem**: Prometheus scraping fails with 404
- **Solution**: Verify the actual API endpoints the service provides

### Test Failures {#test-failures}
- **Problem**: VM tests timeout or fail connectivity
- **Solution**: Check `waitForServices` and `waitForPorts` configurations

### Nixpkgs Integration {#nixpkgs-integration}
- **Problem**: Service options don't match SHB needs
- **Solution**: Map SHB options to nixpkgs options, use `extraConfig` for overrides

## Best Practices Summary {#best-practices-summary}

1. **Follow existing patterns** - study deluge.nix and vaultwarden.nix
2. **Use freeform configuration** - maximum flexibility with typed key options
3. **Implement all contracts** - SSL, backup, monitoring, secrets
4. **Test comprehensively** - all 6 integration variants
5. **Security first** - localhost binding, proper permissions, secret management
6. **Document thoroughly** - clear descriptions for all options
7. **Iterative development** - build complexity gradually
8. **CI/CD validation** - ensure all tests pass before submission

## Redirect Management {#redirect-management}

SelfHostBlocks uses `nixos-render-docs` for documentation generation, which includes built-in redirect validation. The `docs/redirects.json` file maps documentation identifiers to their target URLs.

### Automated Redirect Generation {#automated-redirect-generation}

SelfHostBlocks includes an automated redirect management tool that leverages the official `nixos-render-docs` ecosystem:

```bash
# Generate fresh redirects from HTML documentation
nix run .#update-redirects
```

This tool:
- **Generates HTML documentation** using `nixos-render-docs` with redirect collection enabled
- **Scans actual HTML files** for anchor IDs to ensure perfect accuracy
- **Creates fresh redirects** from scratch by mapping anchors to their real file locations
- **Filters system-generated anchors** (excludes `opt-*` and `selfhostblock*` entries)
- **Provides interactive confirmation** before updating `docs/redirects.json`

### How Redirects Work {#how-redirects-work}

1. **nixos-render-docs validation**: During documentation builds, `nixos-render-docs` automatically validates that all heading IDs have corresponding redirect entries
2. **Automated maintenance**: The `update-redirects` tool automatically maintains `redirects.json` by:
   - Building HTML documentation with patched `nixos-render-docs`
   - Scanning generated HTML files for actual anchor IDs and their file locations
   - Creating accurate redirect mappings without guesswork or pattern matching
3. **Manual override**: You can still manually edit `docs/redirects.json` for special cases

### Redirect Patterns {#redirect-patterns}

The automation follows these patterns when mapping headings to redirect targets:

| Heading ID | Source File | Redirect Target | 
|------------|-------------|-----------------|
| `services-nzbget-basic` | `modules/services/nzbget/docs/default.md` | `["services-nzbget.html#services-nzbget-basic"]` |
| `blocks-monitoring` | `modules/blocks/monitoring/docs/default.md` | `["blocks-monitoring.html#blocks-monitoring"]` |
| `demo-nextcloud` | `demo/nextcloud/README.md` | `["demo-nextcloud.html#demo-nextcloud"]` |
| `contracts` | `docs/contracts.md` | `["contracts.html#contracts"]` |

Note: Redirects always include the anchor link (`#heading-id`) to jump to the specific heading within the target page.

### Adding New Service Documentation {#adding-new-service-documentation}

When implementing a new service, the redirect workflow is now automated:

1. **Write documentation** with heading IDs:
   ```markdown
   # NewService {\#services-newservice}
   ## Basic Configuration {\#services-newservice-basic}
   ```

2. **Update redirects automatically**:
   ```bash
   nix run .#update-redirects
   ```

3. **Review and commit** the changes:
   ```bash
   git add docs/redirects.json modules/services/newservice/docs/default.md
   git commit -m "Add newservice documentation"
   ```

### Build-time Validation {#build-time-validation}

The documentation build process will fail if:
- Any documentation heading ID lacks a corresponding redirect entry
- Redirect targets point to non-existent content  
- There are formatting errors in the redirects file

This ensures documentation links remain functional when content is moved or reorganized.

## Resources {#resources}

- **Contributing guide**: `docs/contributing.md` for authoritative development workflows and testing procedures
- **Existing services**: `modules/services/` for patterns and implementation examples
- **Contracts documentation**: `modules/contracts/` for understanding integration interfaces
- **Test framework**: `test/common.nix` for testing utilities and patterns
- **NixOS options**: https://search.nixos.org/options for upstream service options
- **SHB documentation**: Generated docs showing existing service patterns
- **Redirect automation**: `nix run .#update-redirects` for automated redirect management
- **nixos-render-docs**: Built-in redirect validation and documentation generation

## Quick Reference {#quick-reference}

### Complete Workflow {#complete-workflow}
```bash
# 1. Implement service module
vim modules/services/SERVICENAME.nix

# 2. Create tests  
vim test/services/SERVICENAME.nix

# 3. Update flake
vim flake.nix  # Add to allModules and checks

# 4. Write documentation
vim modules/services/SERVICENAME/docs/default.md

# 5. Generate redirects
nix run .#update-redirects

# 6. Test everything  
nix flake check  # Run all tests (recommended)
# Or test specific variants:
# nix build .#checks.${system}.vm_SERVICENAME_basic
nix build .#manualHtml

# 7. Commit changes
git add .
git commit -m "Add SERVICENAME with full integration"
```

This guide provides a complete roadmap for implementing production-ready SelfHostBlocks services that meet the project's quality standards.
