import subprocess
import sys
import os
import time
import json

def clean_folder_name(folder_name):
    """Clean folder name to make it a single word without spaces or special characters"""
    cleaned_name = folder_name
    result = ""
    for char in cleaned_name:
        if char.isalnum():
            result += char
    if not result:
        result = "RenamedFolder"
    return result

def clean_docker_name(folder_name):
    """Clean folder name to make it Docker-compatible"""
    docker_name = folder_name.lower()
    docker_name = ''.join(c for c in docker_name if c.isalnum() or c == '_')
    while '__' in docker_name:
        docker_name = docker_name.replace('__', '_')
    docker_name = docker_name.strip('_')
    if not docker_name or not docker_name[0].isalnum():
        docker_name = "app_" + docker_name
    if not docker_name or docker_name == "app_":
        docker_name = "myapp"
    if len(docker_name) > 63:
        docker_name = docker_name[:63].rstrip('_')
    return docker_name

BASE_IMAGE = "alpine:3.20"
MIRROR_IMAGE = "mirror.gcr.io/library/alpine:3.20"

def is_image_local(image):
    """Check if a Docker image exists in local cache"""
    result = subprocess.run(f"docker image inspect {image}", shell=True, capture_output=True, text=True)
    return result.returncode == 0

def ensure_base_image(max_retries=3, delay=5):
    """Pull base image with retries, using mirror as fallback. Returns (image_to_use, pull_needed)."""
    if is_image_local(BASE_IMAGE):
        print(f"Base image {BASE_IMAGE} already cached locally - skipping pull")
        return BASE_IMAGE, False

    sources = [BASE_IMAGE, MIRROR_IMAGE]
    for attempt in range(1, max_retries + 1):
        for source in sources:
            print(f"Pulling {source} (attempt {attempt}/{max_retries})...")
            result = subprocess.run(f"docker pull {source}", shell=True, capture_output=False, text=False)
            if result.returncode == 0:
                if source == MIRROR_IMAGE:
                    # Tag mirror image as the canonical name for the build
                    subprocess.run(f"docker tag {MIRROR_IMAGE} {BASE_IMAGE}", shell=True, capture_output=True)
                print(f"Successfully pulled {source}")
                return BASE_IMAGE, True
            print(f"Pull from {source} failed")
        if attempt < max_retries:
            print(f"Retrying in {delay}s...")
            time.sleep(delay)

    print(f"WARNING: Could not pull {BASE_IMAGE} - proceeding anyway (may use BuildKit cache)")
    return BASE_IMAGE, False

def create_dockerfile():
    dockerfile_content = """FROM alpine:3.20
RUN --mount=type=cache,target=/var/cache/apk,sharing=locked apk add rsync
COPY --link . /home/
CMD ["rsync","-aP","/home/","/home/"]
"""
    try:
        with open("Dockerfile", "w", encoding="utf-8") as f:
            f.write(dockerfile_content)
        print("Dockerfile created successfully")
    except Exception as e:
        print(f"Error creating Dockerfile: {e}")

def fast_build_and_push(docker_name):
    """Build image (with progress) then push (with single progress bar).
    Uses tar to pipe build context — automatically skips corrupt/unreadable files."""
    full_tag = f"michadockermisha/backup:{docker_name}"

    # Ensure base image is cached
    ensure_base_image()

    # Step 1: Create Dockerfile
    create_dockerfile()

    # Step 2: Build — tar pipes context, skipping any corrupt/unreadable files
    print(f"\n=== BUILDING {full_tag} ===")
    pull_flag = "--pull=false " if is_image_local(BASE_IMAGE) else ""
    if pull_flag:
        print("(Using cached base image - no registry pull needed)")
    build_cmd = f"tar cf - . 2>nul | docker build {pull_flag}--network=host -t {full_tag} -"
    run_command_as_admin(build_cmd)

    # Step 3: Push — one layer = one clean progress bar
    print(f"\n=== PUSHING {full_tag} ===")
    run_command_as_admin(f"docker push {full_tag}")

DAEMON_JSON_PATH = os.path.expanduser("~/.docker/daemon.json")
REQUIRED_DAEMON_SETTINGS = {
    "dns": ["8.8.8.8", "1.1.1.1", "8.8.4.4"],
    "registry-mirrors": ["https://mirror.gcr.io"],
    "max-concurrent-uploads": 10,
    "max-concurrent-downloads": 10,
}

def ensure_docker_setup():
    """Ensure Docker context is linux and daemon.json has DNS/mirrors/speed. Auto-fixes on reinstall."""
    # 1. Ensure Linux engine context
    ctx_result = subprocess.run("docker context show", shell=True, capture_output=True, text=True)
    current_ctx = ctx_result.stdout.strip()
    if current_ctx != "desktop-linux":
        print(f"Switching Docker context from '{current_ctx}' to 'desktop-linux'...")
        subprocess.run("docker desktop engine use linux", shell=True, capture_output=True)
        subprocess.run("docker context use desktop-linux", shell=True, capture_output=True)

    # 2. Ensure daemon.json has DNS, mirrors, and speed settings
    needs_update = False
    try:
        with open(DAEMON_JSON_PATH, 'r') as f:
            cfg = json.load(f)
    except Exception:
        cfg = {}

    for key, value in REQUIRED_DAEMON_SETTINGS.items():
        if cfg.get(key) != value:
            cfg[key] = value
            needs_update = True

    if needs_update:
        print("Applying Docker daemon settings (DNS, mirrors, speed)...")
        try:
            with open(DAEMON_JSON_PATH, 'w') as f:
                json.dump(cfg, f, indent=2)
            # Reload daemon via SIGHUP (no Docker Desktop restart needed)
            pid_result = subprocess.run(
                "docker run --rm --privileged --pid=host alpine sh -c 'pgrep dockerd'",
                shell=True, capture_output=True, text=True
            )
            if pid_result.returncode == 0 and pid_result.stdout.strip().isdigit():
                dockerd_pid = pid_result.stdout.strip()
                subprocess.run(
                    f"docker run --rm --privileged --pid=host alpine sh -c 'kill -HUP {dockerd_pid}'",
                    shell=True, capture_output=True
                )
                time.sleep(2)
                print("Docker daemon config reloaded.")
            else:
                print("Note: Docker daemon reload skipped (will apply on next restart).")
        except Exception as e:
            print(f"Warning: Could not update daemon.json: {e}")

def start_docker_and_wait(timeout=120):
    """Start Docker Desktop and wait until daemon is ready."""
    print("Starting Docker Desktop...")
    subprocess.Popen(
        r'C:\Program Files\Docker\Docker\Docker Desktop.exe',
        shell=False
    )
    deadline = time.time() + timeout
    while time.time() < deadline:
        result = subprocess.run("docker info", shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print("Docker daemon is ready.")
            return True
        elapsed = int(time.time() - (deadline - timeout))
        print(f"Waiting for Docker daemon... ({elapsed}s)", end='\r', flush=True)
        time.sleep(3)
    print(f"\nDocker daemon did not start within {timeout}s.")
    return False

def check_docker_status():
    """Check if Docker is running; auto-start if not."""
    try:
        result = subprocess.run("docker --version", shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            print("Docker is not installed or not in PATH")
            return False
        print(f"Docker version: {result.stdout.strip()}")
        result = subprocess.run("docker info", shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print("Docker daemon is running")
            return True
        # Daemon not running — try to start it
        return start_docker_and_wait()
    except Exception as e:
        print(f"Error checking Docker status: {e}")
        return False

DNS_ERROR_KEYWORDS = [
    "getaddrinfow", "dial tcp", "failed to authorize", "failed to fetch oauth token",
    "failed to resolve source metadata", "no data of the requested type"
]

def is_dns_error(text):
    return any(kw in text.lower() for kw in DNS_ERROR_KEYWORDS)

def kill_process_tree(pid):
    """Kill a process and all its children (fixes shell=True orphan issue on Windows)."""
    subprocess.run(f"taskkill /F /T /PID {pid}", shell=True, capture_output=True)

def run_command_as_admin(command, max_retries=5, delay=10):
    is_push = command.strip().startswith("docker push")
    last_error = None
    for attempt in range(1, max_retries + 1):
        try:
            # Inherited stdout/stderr: Docker writes directly to terminal → real-time progress
            proc = subprocess.Popen(command, shell=True)
            proc.wait()  # no timeout — large layers can take 30+ min, killing restarts from 0
            if proc.returncode == 0:
                return
            if is_push and attempt < max_retries:
                print(f"\nPush failed (exit {proc.returncode}) — retrying in {delay}s (attempt {attempt}/{max_retries})...")
                time.sleep(delay)
                last_error = subprocess.CalledProcessError(proc.returncode, command)
                continue
            raise subprocess.CalledProcessError(proc.returncode, command)
        except FileNotFoundError as e:
            print(f"File not found error: {e}")
            print("Note: Make sure Docker Desktop is running and you're in the correct environment")
            raise
    if last_error:
        print(f"Error: {last_error}")
        raise last_error

def get_input(prompt):
    return input(prompt).strip()

def run_selected_commands(selected_commands):
    build_cmd_index = None
    # Find the build command index so we can pre-pull before it
    for i, command in enumerate(selected_commands):
        if "docker build" in command:
            build_cmd_index = i
            break

    if build_cmd_index is not None:
        ensure_base_image()

    for command in selected_commands:
        print(f"\nExecuting: {command}")
        try:
            if command.startswith("PYTHON_FUNCTION:"):
                function_name = command.split(":", 1)[1]
                if function_name == "create_dockerfile":
                    create_dockerfile()
                continue
            if '-it' in command:
                print("Note: Interactive command detected. If container doesn't exist, this will fail.")
            # For build commands: if image is local, add --pull=false to skip registry fetch
            if "docker build" in command and is_image_local(BASE_IMAGE):
                if "--pull=false" not in command and "--pull=never" not in command:
                    command = command.replace("docker build", "docker build --pull=false", 1)
                    print(f"(Using cached base image - no registry pull needed)")
            run_command_as_admin(command)
        except Exception as e:
            print(f"Error executing command: {e}")
            continue

def main():
    commands = [
        {"name": "KillAll", "command": 'docker stop $(docker ps -aq) 2>/dev/null || true && docker rm $(docker ps -aq) 2>/dev/null || true && docker rmi $(docker images -q) 2>/dev/null || true && docker system prune -a --volumes --force && docker network prune --force'},
        {"name": "Pull Docker Image", "command": "docker pull michadockermisha/backup:<choosename>"},
        {"name": "Run Docker Container", "command": "docker run -v F:\\:/f/ -it --name <choosename> michadockermisha/backup:<choosename><endcommand>"},
        {"name": "Create Dockerfile", "command": "PYTHON_FUNCTION:create_dockerfile"},
        {"name": "Build Docker Image", "command": "tar cf - . 2>nul | docker build --network=host -t michadockermisha/backup:<choosename> -"},
        {"name": "Push Docker Image (standalone)", "command": "docker push michadockermisha/backup:<choosename>"},
        {"name": "Compose up", "command": "docker-compose up -d <choosename>"},
        {"name": "Compose down", "command": "docker-compose down"},
        {"name": "Start container", "command": "docker exec -it <choosename> <endcommand>"},
        {"name": "Container IP", "command": "docker inspect -f \"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}\" <choosename>"},
        {"name": "Show Containers Running", "command": "docker ps --size"},
        {"name": "Show ALL Containers", "command": "docker ps -a --size"},
        {"name": "Show Images", "command": "docker images"},
        {"name": "SEARCH", "command": "docker search <searchterm>"},
        {"name": "Update System Packages", "command": "winget upgrade --all"},
        {"name": "Scan System Health", "command": "docker info"},
        {"name": "Restart Docker Service", "command": "echo 'Restart Docker Desktop manually'"},
    ]

    if len(sys.argv) > 1:
        original_folder_path = sys.argv[1]
        print("=== Docker Management Script ===")
        print("Note: Dockerfile optimized for maximum speed")
        print("Make sure Docker Desktop is running")
        print("=" * 40)

        if not os.path.exists(original_folder_path):
            print(f"Error: Folder '{original_folder_path}' does not exist.")
            return

        parent_dir = os.path.dirname(original_folder_path)
        original_folder_name = os.path.basename(original_folder_path)
        cleaned_folder_name = clean_folder_name(original_folder_name)
        new_folder_path = os.path.join(parent_dir, cleaned_folder_name)

        if original_folder_name != cleaned_folder_name:
            try:
                print(f"Renaming folder: '{original_folder_name}' -> '{cleaned_folder_name}'")
                os.rename(original_folder_path, new_folder_path)
                print(f"Folder renamed successfully")
            except Exception as e:
                print(f"Error renaming folder: {e}")
                return
        else:
            print(f"Folder name already clean: '{original_folder_name}'")
            new_folder_path = original_folder_path

        try:
            os.chdir(new_folder_path)
            print(f"Changed directory to: {os.getcwd()}")
        except Exception as e:
            print(f"Error changing directory: {e}")
            return

        print("\nChecking Docker status...")
        if not check_docker_status():
            print("Docker is not available. Please start Docker Desktop and try again.")
            return
        ensure_docker_setup()

        folder_name_only = cleaned_folder_name

        print(f"Checking for existing container '{cleaned_folder_name}'...")
        try:
            subprocess.run(f"docker rm -f {cleaned_folder_name}", shell=True, capture_output=True)
            print(f"Removed existing container '{cleaned_folder_name}' if it existed")
        except:
            pass

        docker_name = clean_docker_name(folder_name_only)
        
        # Max speed environment variables
        os.environ['DOCKER_BUILDKIT'] = '1'
        os.environ['BUILDKIT_INLINE_CACHE'] = '1'
        os.environ['BUILDKIT_PROGRESS'] = 'auto'
        os.environ['DOCKER_CONTENT_TRUST'] = '0'

        print(f"\nBuild + Push for folder:")
        print(f"  Original: '{original_folder_name}'")
        print(f"  Cleaned:  '{cleaned_folder_name}'")
        print(f"  Docker:   '{docker_name}'")
        print(f"Working directory: {os.getcwd()}")
        print("Order: Build (with progress) → Push (with progress bar)")

        fast_build_and_push(docker_name)
        return

    while True:
        print("\nDocker Menu:")
        for i, cmd in enumerate(commands, 1):
            print(f"{i}. {cmd['name']}")
        print("0. Exit")

        choice = get_input("\nEnter the numbers of the commands you want to run (comma-separated) or 0 to exit: ")

        if choice == '0':
            break

        selected_commands = []
        for num in choice.split(','):
            try:
                index = int(num.strip()) - 1
                if 0 <= index < len(commands):
                    cmd = commands[index]
                    command = cmd["command"]

                    if '<choosename>' in command:
                        name = get_input("Enter name: ")
                        command = command.replace('<choosename>', name)

                        if '<endcommand>' in command:
                            end_command = get_input("Enter end command (e.g., bash, sh, cmd, powershell) or leave blank: ")
                            end_command = f" {end_command}" if end_command else ""
                            command = command.replace('<endcommand>', end_command)

                    elif '<searchterm>' in command:
                        search_term = get_input("Enter search term: ")
                        command = command.replace('<searchterm>', search_term)

                    selected_commands.append(command)
                else:
                    print(f"Invalid number: {num}")
            except ValueError:
                print(f"Invalid input: {num}")

        if selected_commands:
            print("\nSelected commands:")
            for cmd in selected_commands:
                print(cmd)

            confirm = get_input("\nDo you want to run these commands? (y/n): ")
            if confirm.lower() == 'y':
                run_selected_commands(selected_commands)
            else:
                print("Commands not executed.")

if __name__ == "__main__":
    main()
