# wingit.ps1
# Installs / updates all needed apps, skipping ones already installed.
# Packages are organized in a clear list to easily add/remove in the future.

$ErrorActionPreference = "SilentlyContinue"

Write-Host "=== WINGIT: PATH fix + app install ===" -ForegroundColor Cyan

# ------------------------------
# 1) PATH entries (easy to edit)
# ------------------------------
$pathsToAdd = @(
    "C:\Program Files\GitHub CLI",
    "C:\Program Files\Git\cmd",
    "C:\Program Files (x86)\Google\Chrome\Application",
    "C:\Program Files\Seerge\G-Helper",
    "C:\Program Files\Asus\Armoury Crate"
)

$pathParts = $env:Path -split ';' | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() }

foreach ($p in $pathsToAdd) {
    if (-not ($pathParts -contains $p)) {
        Write-Host "Adding to PATH: $p" -ForegroundColor Yellow
        $pathParts += $p
    }
}

$env:Path = ($pathParts -join ';')
[Environment]::SetEnvironmentVariable('Path', $env:Path, [EnvironmentVariableTarget]::User)

# -----------------------------------------
# 2) PACKAGE LIST – EDIT THIS BLOCK ONLY
# -----------------------------------------
# Id   = winget / MS Store package Id
# Source:
#   $null   = default winget sources
#   "msstore" = Microsoft Store

$packages = @(
    # === Browsers / UI ===
    @{ Id = "google.chrome";           Source = $null      } # Google Chrome

    # === System utilities / helpers ===
    @{ Id = "Rclone.Rclone";           Source = $null      } # Rclone
    @{ Id = "GitHub.cli";              Source = $null      } # GitHub CLI
    @{ Id = "j178.ChatGPT";            Source = $null      } # ChatGPT client
    @{ Id = "seerge.g-helper";         Source = $null      } # G-Helper
    @{ Id = "Asus.ArmouryCrate";       Source = $null      } # Armoury Crate

    # === Store apps (MS Store IDs) ===
    @{ Id = "9NCVDN91XZQP";            Source = "msstore"  }
    @{ Id = "9MWF2DWS5Z9N";            Source = "msstore"  }
    @{ Id = "9N7R5S6B0ZZH";            Source = "msstore"  }
    @{ Id = "9WZDNCRDK3WP";            Source = "msstore"  }
    @{ Id = "9NHPXCXS27F9";            Source = "msstore"  }
    @{ Id = "9NT1R1C2HH7J";            Source = "msstore"  }

    # === Apps / tools ===
    @{ Id = "KristenMcWilliam.Nyrna";  Source = $null      } # Nyrna
    @{ Id = "Anthropic.Claude";        Source = $null      } # Claude
    @{ Id = "Perplexity.Comet";        Source = $null      } # Comet
)

# To add a new package:
#   @{ Id = "Some.Package.Id"; Source = $null }           # or "msstore"
# To remove a package:
#   Just delete its line.

# -----------------------------------------
# 3) Install only when not already present
# -----------------------------------------

# Ensure winget exists
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: winget not found. Install App Installer from MS Store." -ForegroundColor Red
    exit 1
}

foreach ($pkg in $packages) {
    $id     = $pkg.Id
    $source = $pkg.Source

    Write-Host "`n=== Checking: $id ===" -ForegroundColor Cyan

    $listArgs = @(
        "list",
        "--accept-source-agreements",
        "--exact",
        "--id", $id
    )
    if ($source) { $listArgs += @("--source", $source) }

    $installedOutput = winget @listArgs 2>$null

    if (-not $installedOutput -or $installedOutput -match "No installed package found") {
        Write-Host "Not installed or not found, installing: $id" -ForegroundColor Yellow

        $installArgs = @(
            "install",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--ignore-security-hash",
            "--skip-dependencies",
            "--exact",
            "--id", $id
        )
        if ($source) { $installArgs += @("--source", $source) }

        winget @installArgs
    }
    else {
        Write-Host "Already installed, skipping: $id" -ForegroundColor Green
    }
}

Write-Host "`n=== WINGIT DONE ===" -ForegroundColor Green
