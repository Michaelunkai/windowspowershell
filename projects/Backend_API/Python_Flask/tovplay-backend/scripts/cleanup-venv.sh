#!/bin/bash
# Script to clean up virtual environment files from the repository

# Remove the venv directory from git tracking
git rm -r --cached venv/

# Add venv to .gitignore if not already there
if ! grep -q "venv/" .gitignore; then
    echo "" >> .gitignore
    echo "# Virtual environment" >> .gitignore
    echo "venv/" >> .gitignore
fi

echo "Virtual environment removed from git tracking. Please commit these changes."