#!/usr/bin/env python3
"""
Generate redirects.json by scanning actual HTML files produced by nixos-render-docs.

This script implements a runtime patching mechanism to automatically generate a
complete redirects.json file by scanning generated HTML files for real anchor
locations, eliminating manual maintenance and ensuring accuracy.

ARCHITECTURE OVERVIEW:
The script works by monkey-patching nixos-render-docs at runtime to:
1. Disable redirect validation during HTML generation
2. Generate HTML documentation normally
3. Scan all generated HTML files to extract anchor IDs and their file locations
4. Apply filtering logic to exclude system-generated anchors
5. Generate and write redirects.json with accurate mappings

KEY COMPONENTS:
- Runtime patching: Modifies nixos-render-docs behavior without source changes
- HTML scanning: Extracts anchor IDs using regex pattern matching
- Filtering: Excludes NixOS options (opt-*) and extra options (selfhostblock*)
- Output generation: Creates both debug information and production redirects.json

IMPORTANT NOTES:
- Uses atexit handler to ensure output is generated even if process is interrupted
- Patches are applied on module import, making this a side-effect import
- Error handling preserves original validation behavior in case of failure
"""

import sys
import json
import atexit
import os
import re

# Global storage for anchor-to-file mappings discovered during HTML scanning
# Structure: {anchor_id: html_filename}
file_target_mapping = {}

def scan_html_files(output_dir, html_files):
    """
    Scan HTML files to extract anchor IDs and build anchor-to-file mappings.
    
    Discovers all HTML files in output_dir and extracts id attributes to populate
    the global file_target_mapping. Filters out NixOS system options during scanning.
    
    Args:
        output_dir: Directory containing generated HTML files
        html_files: Unused parameter (always discovers files from filesystem)
    """
    # Always discover HTML files from the output directory
    if not os.path.exists(output_dir):
        print(f"DEBUG: Output directory {output_dir} does not exist", file=sys.stderr)
        return
    
    html_files = [f for f in os.listdir(output_dir) if f.endswith('.html')]
    print(f"DEBUG: Discovered {len(html_files)} HTML files in {output_dir}", file=sys.stderr)
    
    # Process each HTML file to extract anchor IDs
    for html_file in html_files:
        html_path = os.path.join(output_dir, html_file)
        try:
            with open(html_path, 'r', encoding='utf-8') as f:
                html_content = f.read()
            
            # Extract all id attributes using regex pattern matching
            # Matches: id="anchor-name" and captures anchor-name
            anchor_matches = re.findall(r'id="([^"]+)"', html_content)
            
            # Filter and record anchor mappings
            non_opt_count = 0
            for anchor_id in anchor_matches:
                # Skip NixOS system option anchors (opt-* prefix)
                if not anchor_id.startswith('opt-'):
                    file_target_mapping[anchor_id] = html_file
                    non_opt_count += 1
            
            if non_opt_count > 0:
                print(f"Found {non_opt_count} anchors in {html_file}", file=sys.stderr)
                
        except Exception as e:
            # Log errors but continue processing other files
            print(f"Failed to scan {html_path}: {e}", file=sys.stderr)

def output_collected_refs():
    """
    Generate and write the final redirects.json file from collected anchor mappings.
    
    This function is registered as an atexit handler to ensure output is generated
    even if the process is interrupted. It processes the global file_target_mapping
    to create the final redirects file with appropriate filtering.
    
    Output files:
        - out/redirects.json: Production redirects mapping
    """
    import os
    
    # Generate redirects from discovered HTML anchor mappings
    if file_target_mapping:
        print(f"Creating redirects from {len(file_target_mapping)} HTML mappings", file=sys.stderr)
        redirects = {}
        filtered_count = 0
        
        # Apply filtering logic to exclude system-generated anchors
        for anchor_id, html_file in file_target_mapping.items():
            # Filter out:
            # - opt-*: NixOS system options 
            # - selfhostblock*: Extra options from this project
            if not anchor_id.startswith('opt-') and not anchor_id.startswith('selfhostblock'):
                redirects[anchor_id] = [f"{html_file}#{anchor_id}"]
            else:
                filtered_count += 1
        
        print(f"Generated {len(redirects)} redirects (filtered out {filtered_count} system options)", file=sys.stderr)
    else:
        # Fallback case - should not occur during normal operation
        print("Warning: No HTML mappings available", file=sys.stderr)
        redirects = {}
    
    # Ensure output directory exists
    os.makedirs('out', exist_ok=True)
    
    # Write production redirects file
    try:
        redirects_file = 'out/redirects.json'
        
        with open(redirects_file, 'w') as f:
            json.dump(redirects, f, indent=2, sort_keys=True)
        
        print(f"Generated redirects.json with {len(redirects)} redirects", file=sys.stderr)
        
    except Exception as e:
        print(f"Failed to write redirects.json: {e}", file=sys.stderr)

# Register output generation to run on process exit
atexit.register(output_collected_refs)

def apply_patches():
    """
    Apply runtime monkey patches to nixos-render-docs modules.
    
    This function modifies the behavior of nixos-render-docs by:
    1. Hooking into the HTML generation CLI command
    2. Temporarily disabling redirect validation during HTML generation
    3. Scanning generated HTML files to extract anchor mappings
    4. Restoring original validation behavior
    
    The patching approach allows us to extract anchor information without
    modifying the nixos-render-docs source code directly.
    
    Raises:
        ImportError: If nixos-render-docs modules cannot be imported
    """
    try:
        # Import required nixos-render-docs modules
        import nixos_render_docs.html as html_module
        import nixos_render_docs.redirects as redirects_module
        import nixos_render_docs.manual as manual_module
        
        # Store reference to original HTML CLI function
        original_run_cli_html = manual_module._run_cli_html
        
        def patched_run_cli_html(args):
            """
            Patched version of _run_cli_html that disables validation and scans output.
            
            This wrapper function:
            1. Temporarily disables redirect validation to prevent errors
            2. Runs normal HTML generation
            3. Scans generated HTML files for anchor mappings
            4. Restores original validation behavior
            """
            print("Generating HTML documentation...", file=sys.stderr)
            
            # Temporarily disable redirect validation
            original_validate = redirects_module.Redirects.validate
            redirects_module.Redirects.validate = lambda self, targets: None
            
            try:
                # Run original HTML generation
                result = original_run_cli_html(args)
                
                # Determine output directory from CLI arguments
                if hasattr(args, 'outfile') and args.outfile:
                    output_dir = os.path.dirname(args.outfile)
                else:
                    output_dir = '.'
                
                # Scan generated HTML files for anchor mappings
                scan_html_files(output_dir, None)
                print(f"Scanned {len(file_target_mapping)} anchor mappings", file=sys.stderr)
                
            finally:
                # Always restore original validation function
                redirects_module.Redirects.validate = original_validate
            
            return result
        
        # Replace the original function with our patched version
        manual_module._run_cli_html = patched_run_cli_html
                
        print("Applied patches to nixos-render-docs", file=sys.stderr)
        
    except ImportError as e:
        print(f"Failed to apply patches: {e}", file=sys.stderr)

# Apply patches immediately when this module is imported
# This ensures the patches are active before nixos-render-docs CLI runs
apply_patches()