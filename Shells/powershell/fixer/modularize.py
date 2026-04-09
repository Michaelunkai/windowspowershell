#!/usr/bin/env python3
"""
Modularize Windows Repair Script - Splits large a.ps1 into 13 smaller modules
This script extracts initialization code and phases into separate files
"""

import os
import re
from pathlib import Path

def main():
    input_file = r"F:\study\shells\powershell\fixer\a.ps1"
    output_dir = r"F:\study\shells\powershell\fixer\modules"

    # Create output directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    # Read entire file
    with open(input_file, 'r', encoding='utf-8-sig') as f:
        content = f.read()

    lines = content.split('\n')

    # Find all Phase markers
    phases = []
    for i, line in enumerate(lines):
        match = re.match(r'^\s*Phase\s+"([^"]+)"', line)
        if match:
            phases.append({'line': i, 'name': match.group(1), 'index': len(phases) + 1})

    print(f"Found {len(phases)} phases in {len(lines)} lines")

    # Find initialization section end (before first Phase)
    init_end = phases[0]['line'] if phases else len(lines)

    # Extract initialization (0-802 lines before first Phase)
    init_content = '\n'.join(lines[:init_end])

    # Create initialization module
    init_module = init_content
    with open(os.path.join(output_dir, 'script_00_init.ps1'), 'w', encoding='utf-8') as f:
        f.write(init_module)
    print(f"[OK] Created script_00_init.ps1 ({init_end} lines)")

    # Define phase groupings (13 scripts total)
    phase_groups = [
        (1, 1, "script_01_restore_point"),        # Phase 1
        (2, 8, "script_02-08_system_state"),      # Phases 2-8
        (9, 15, "script_09-15_boot_drivers"),     # Phases 9-15
        (16, 25, "script_16-25_drivers_dism"),    # Phases 16-25
        (26, 35, "script_26-35_dotnet_power"),    # Phases 26-35
        (36, 45, "script_36-45_network_gpu"),     # Phases 36-45
        (46, 50, "script_46-50_services_dcom"),   # Phases 46-50
        (51, 60, "script_51-60_hns_boot"),        # Phases 51-60
        (61, 70, "script_61-70_gaming_wsldns"),   # Phases 61-70
        (71, 80, "script_71-80_dism_storage"),    # Phases 71-80
        (81, 92, "script_81-92_nuclear_final"),   # Phases 81-92
    ]

    # Extract and save phase groups
    for start_phase, end_phase, filename in phase_groups:
        # Find line ranges
        start_line = None
        end_line = len(lines)

        for phase in phases:
            if phase['index'] == start_phase:
                start_line = phase['line']
            if phase['index'] == end_phase + 1:
                end_line = phase['line']
                break

        if start_line is None:
            continue

        # Extract content including header functions and helper functions
        content_lines = init_content.split('\n') + lines[start_line:end_line]
        module_content = '\n'.join(content_lines)

        # Write module
        with open(os.path.join(output_dir, f'{filename}.ps1'), 'w', encoding='utf-8') as f:
            f.write(module_content)

        phase_desc = f"Phase {start_phase}" if start_phase == end_phase else f"Phases {start_phase}-{end_phase}"
        print(f"[OK] Created {filename}.ps1 ({phase_desc})")

    print("\n[OK] Modularization complete!")
    print(f"Created 13 modular scripts in {output_dir}")

if __name__ == '__main__':
    main()
