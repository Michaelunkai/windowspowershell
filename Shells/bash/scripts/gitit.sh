#!/bin/bash
# gitit - Force push ANY folder to GitHub
# Uses the Python script for bulletproof operation

gitit() {
    local target="${1:-.}"
    
    # Convert Windows path if running in WSL
    if [[ "$target" == *":"* ]]; then
        target=$(wslpath -u "$target" 2>/dev/null || echo "$target")
    fi
    
    # Run the Python script
    python "F:/study/Version_control/git/gitit/a.py" "$target"
}

# If called directly (not sourced), run with arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gitit "$@"
fi
