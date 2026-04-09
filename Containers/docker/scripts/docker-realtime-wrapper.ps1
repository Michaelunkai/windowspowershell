# Docker Real-Time Progress Wrapper (FIXED - NO --progress for pull)
# This forces ALL docker commands to show real-time progress without buffering
# Add to PowerShell profile: . "F:\study\containers\docker\scripts\docker-realtime-wrapper.ps1"

# Force Docker environment variables for real-time progress
$env:DOCKER_BUILDKIT = "1"
$env:BUILDKIT_PROGRESS = "plain"
$env:DOCKER_CLI_EXPERIMENTAL = "enabled"
$env:COMPOSE_DOCKER_CLI_BUILD = "1"

# Original docker executable path
$script:DockerExe = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"

# Ensure correct context (desktop-linux works with Hyper-V backend)
& $script:DockerExe context use desktop-linux 2>&1 | Out-Null

# Wrapper function that forces real-time output
function docker {
    # Use $args to avoid PowerShell parsing -e/-v etc as PS parameters
    $Arguments = $args

    # Force unbuffered output
    $PSDefaultParameterValues['Out-Default:OutVariable'] = 'null'

    # Parse command to add --progress=plain ONLY to build (NOT pull/push)
    $modifiedArgs = @()
    $command = $Arguments[0]

    if ($command -eq 'build') {
        # Add --progress=plain if not already present
        if ($Arguments -notcontains '--progress') {
            $modifiedArgs += $command
            $modifiedArgs += '--progress=plain'
            $modifiedArgs += $Arguments[1..($Arguments.Length - 1)]
        } else {
            $modifiedArgs = $Arguments
        }
    } else {
        # For pull, push, run, etc. - use as-is (they don't support --progress)
        $modifiedArgs = $Arguments
    }

    # Run docker - pass all output through pipeline (enables both capture AND real-time display)
    & $script:DockerExe @modifiedArgs 2>&1
}

Write-Host "[Docker Wrapper] Real-time progress enabled (build commands only)" -ForegroundColor Green
