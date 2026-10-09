Interview Introduction
"This script is a GitLab Runner maintenance script that we use on our self-hosted runner server. The main purpose is to automatically clean unused Podman images, containers, volumes, old build artifacts, and cache files to prevent disk space issues. It also ensures the GitLab Runner service is safely stopped during cleanup and automatically restarted even if the script fails."

High-Level Flow
1. Create lock file
2. Start logging
3. Stop GitLab Runner
4. Run Podman cleanup
5. Delete old build/cache files
6. Delete temporary files
7. Restart GitLab Runner
8. Write cleanup completion logs

Step 1: Logging
LOGFILE="/var/log/gitlab-runner-cleanup.log"

What it does
Stores all cleanup activity in a log file.
Why
If cleanup fails, we can troubleshoot using logs.
Interview answer:
"We maintain a dedicated log file so that every cleanup operation is auditable and easy to troubleshoot."

Step 2: Lock File
LOCKFILE="/var/run/gitlab-runner-cleanup.lock"

exec 9>$LOCKFILE
flock -n 9 || exit 0

What it does
Creates a lock file and acquires an exclusive lock.
Why
Prevents multiple executions of the script simultaneously.
Example:
Suppose cron triggers the script every hour.
First execution:
Cleanup running

Second execution starts before first finishes:
Exit immediately

Without lock:
Two cleanup jobs
Deleting same files
Possible corruption

Interview answer:
"We use flock to ensure only one cleanup job runs at a time, avoiding race conditions."

Step 3: Trap Function
trap cleanup_finish EXIT

What it does
Runs cleanup_finish() whenever the script exits.
Even if:
Success
Failure
Unexpected exit

Why
Ensures GitLab Runner always comes back online.
Interview answer:
"The trap guarantees runner availability by automatically restarting GitLab Runner even if cleanup fails."

Step 4: Stop GitLab Runner
systemctl stop gitlab-runner

What it does
Stops the runner service.
Why
Avoids deleting files that active jobs are using.
Without stopping:
Pipeline running
Cleanup deletes build directory
Pipeline fails

Interview answer:
"We stop the runner first to avoid conflicts with running CI jobs."

Step 5: Podman Migration
podman system migrate

What it does
Updates Podman internal state.
Why
Sometimes after upgrades Podman metadata becomes outdated.
This command synchronizes:
Storage metadata
Runtime configuration
Container state

Interview answer:
"We run podman system migrate to ensure container storage metadata remains consistent after Podman upgrades."

Step 6: Remove Unused Containers
podman container prune -f

What it does
Deletes stopped containers.
Why
CI pipelines create many temporary containers.
Example:
Pipeline 1 container
Pipeline 2 container
Pipeline 3 container

All completed.
No longer needed.
Interview answer:
"Container prune removes stopped containers that consume unnecessary disk space."

Step 7: Remove Unused Images
podman image prune -a -f

What it does
Deletes unused images.
Why
Images are usually the biggest disk consumers.
Example:
python:3.9
python:3.10
ubuntu:20.04
ubuntu:22.04

Unused images accumulate quickly.
Interview answer:
"Image pruning helps reclaim significant disk space by removing images not associated with active containers."

Step 8: Remove Unused Volumes
podman volume prune -f

What it does
Deletes unused storage volumes.
Why
Volumes remain even after containers are removed.
Interview answer:
"Unused volumes can accumulate over time, so we periodically clean them to recover storage."

Step 9: Delete Old Builds
find /home/gitlab-runner/builds -mtime +7

What it does
Deletes build artifacts older than 7 days.
Why
Build directories grow continuously.
Example:
build-1
build-2
build-3

After several weeks:
Hundreds of GB

Interview answer:
"We retain build artifacts for seven days and automatically remove older builds to optimize disk usage."

Step 10: Delete Old Cache
find /home/gitlab-runner/cache -mtime +7

What it does
Deletes cache older than seven days.
Why
Caches improve performance but grow indefinitely.
Interview answer:
"Old cache files are removed after seven days to balance storage utilization and pipeline performance."

Step 11: Remove Temporary Files
find /home/gitlab-runner -name "*.tmp"

What it does
Deletes temporary files older than 3 days.
Why
Temporary files are not needed long term.
Interview answer:
"Temporary files are cleaned regularly to avoid unnecessary storage consumption."

Step 12: Clean Podman Temp Storage
find ~/.local/share/containers/storage/tmp

What it does
Removes old Podman temporary files.
Why
Podman creates temporary layers and files during image pulls and builds.
Interview answer:
"Podman temporary storage can accumulate stale files, so we periodically clean them."
