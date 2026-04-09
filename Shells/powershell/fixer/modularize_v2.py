#!/usr/bin/env python3
"""
Advanced Modularization - Properly extracts phase code blocks
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

    # Step 1: Find initialization section (everything before first Phase call)
    init_end = None
    phase_starts = []

    for i, line in enumerate(lines):
        if re.match(r'^\s*Phase\s+"', line):
            if init_end is None:
                init_end = i
            phase_starts.append((i, line))

    print(f"Found {len(phase_starts)} phases")
    print(f"Initialization ends at line {init_end}")

    # Step 2: Extract initialization module (shared by all)
    init_module = '\n'.join(lines[:init_end])
    with open(os.path.join(output_dir, 'script_00_init.ps1'), 'w', encoding='utf-8') as f:
        f.write(init_module)
    print(f"[OK] Created script_00_init.ps1 ({init_end} lines)")

    # Step 3: Define which phases go into which modules
    # This maps phase numbers to module files
    phase_to_module = {
        1: "script_01_restore_point",
        2: "script_02-08_system_state", 3: "script_02-08_system_state", 4: "script_02-08_system_state",
        5: "script_02-08_system_state", 6: "script_02-08_system_state", 7: "script_02-08_system_state",
        8: "script_02-08_system_state",
        9: "script_09-15_boot_drivers", 10: "script_09-15_boot_drivers", 11: "script_09-15_boot_drivers",
        12: "script_09-15_boot_drivers", 13: "script_09-15_boot_drivers", 14: "script_09-15_boot_drivers",
        15: "script_09-15_boot_drivers",
        16: "script_16-25_drivers_dism", 17: "script_16-25_drivers_dism", 18: "script_16-25_drivers_dism",
        19: "script_16-25_drivers_dism", 20: "script_16-25_drivers_dism", 21: "script_16-25_drivers_dism",
        22: "script_16-25_drivers_dism", 23: "script_16-25_drivers_dism", 24: "script_16-25_drivers_dism",
        25: "script_16-25_drivers_dism",
        26: "script_26-35_dotnet_power", 27: "script_26-35_dotnet_power", 28: "script_26-35_dotnet_power",
        29: "script_26-35_dotnet_power", 30: "script_26-35_dotnet_power", 31: "script_26-35_dotnet_power",
        32: "script_26-35_dotnet_power", 33: "script_26-35_dotnet_power", 34: "script_26-35_dotnet_power",
        35: "script_26-35_dotnet_power",
        36: "script_36-45_network_gpu", 37: "script_36-45_network_gpu", 38: "script_36-45_network_gpu",
        39: "script_36-45_network_gpu", 40: "script_36-45_network_gpu", 41: "script_36-45_network_gpu",
        42: "script_36-45_network_gpu", 43: "script_36-45_network_gpu", 44: "script_36-45_network_gpu",
        45: "script_36-45_network_gpu",
        46: "script_46-50_services_dcom", 47: "script_46-50_services_dcom", 48: "script_46-50_services_dcom",
        49: "script_46-50_services_dcom", 50: "script_46-50_services_dcom",
        51: "script_51-60_hns_boot", 52: "script_51-60_hns_boot", 53: "script_51-60_hns_boot",
        54: "script_51-60_hns_boot", 55: "script_51-60_hns_boot", 56: "script_51-60_hns_boot",
        57: "script_51-60_hns_boot", 58: "script_51-60_hns_boot", 59: "script_51-60_hns_boot",
        60: "script_51-60_hns_boot",
        61: "script_61-70_gaming_wsldns", 62: "script_61-70_gaming_wsldns", 63: "script_61-70_gaming_wsldns",
        64: "script_61-70_gaming_wsldns", 65: "script_61-70_gaming_wsldns", 66: "script_61-70_gaming_wsldns",
        67: "script_61-70_gaming_wsldns", 68: "script_61-70_gaming_wsldns", 69: "script_61-70_gaming_wsldns",
        70: "script_61-70_gaming_wsldns",
        71: "script_71-80_dism_storage", 72: "script_71-80_dism_storage", 73: "script_71-80_dism_storage",
        74: "script_71-80_dism_storage", 75: "script_71-80_dism_storage", 76: "script_71-80_dism_storage",
        77: "script_71-80_dism_storage", 78: "script_71-80_dism_storage", 79: "script_71-80_dism_storage",
        80: "script_71-80_dism_storage",
        81: "script_81-92_nuclear_final", 82: "script_81-92_nuclear_final", 83: "script_81-92_nuclear_final",
        84: "script_81-92_nuclear_final", 85: "script_81-92_nuclear_final", 86: "script_81-92_nuclear_final",
        87: "script_81-92_nuclear_final", 88: "script_81-92_nuclear_final", 89: "script_81-92_nuclear_final",
        90: "script_81-92_nuclear_final", 91: "script_81-92_nuclear_final", 92: "script_81-92_nuclear_final",
    }

    # Step 4: Group phases by module and extract
    modules_content = {}

    for module_name in set(phase_to_module.values()):
        modules_content[module_name] = []

    # Extract each phase and add to its module
    for phase_num in range(1, 93):
        module_name = phase_to_module.get(phase_num)
        if not module_name:
            continue

        # Find this phase's start and next phase's start
        phase_start = None
        phase_end = None

        for idx, (line_num, line_text) in enumerate(phase_starts):
            match = re.search(r'Phase\s+"([^"]+)"', line_text)
            if match:
                # Extract phase number from line number position
                # Count how many phases we've seen
                current_phase_num = idx + 1

                if current_phase_num == phase_num:
                    phase_start = line_num
                    # Next phase starts at the next phase line number, or end of file
                    if idx + 1 < len(phase_starts):
                        phase_end = phase_starts[idx + 1][0]
                    else:
                        phase_end = len(lines)
                    break

        if phase_start is not None and phase_end is not None:
            phase_code = '\n'.join(lines[phase_start:phase_end])
            modules_content[module_name].append(phase_code)

    # Write each module
    for module_name, phase_codes in modules_content.items():
        # Combine init + phase codes
        module_content = init_module + "\n\n" + "\n\n".join(phase_codes)

        file_path = os.path.join(output_dir, f'{module_name}.ps1')
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(module_content)

        print(f"[OK] Created {module_name}.ps1 ({len(phase_codes)} phases)")

    print("\n[OK] Modularization v2 complete!")

if __name__ == '__main__':
    main()
