#!/bin/bash

# ============================================================
# ACME PODMAN EXAM
# ENVIRONMENT PREPARATION SCRIPT
# ============================================================
#
# Usage:
#
#     ./prepare_exam_environment.sh
#
# This script prepares the examination environment for the
# CURRENT USER.
#
# It uses:
#
#     $HOME
#
# automatically, so there is NO need to provide a username.
#
# ============================================================
#
# The script prepares:
#
#   workspace1/
#   workspace2/
#   workspace4/
#
# It creates:
#
#   - Task 1 HTML file
#   - Task 2 HTML file
#   - Task 2 Nginx configuration
#   - Task 4.1 MariaDB Containerfile
#   - Task 4.2 MariaDB export Containerfile
#   - Task 4.2 export.sh
#
# It also prepares the local registry.
#
# The script DOES NOT:
#
#   - Pull exam images
#   - Install Podman
#   - Check Podman Compose
#   - Create exam containers
#   - Create exam networks
#   - Create exam volumes
#
# ============================================================

set -euo pipefail

# ============================================================
# VARIABLES
# ============================================================

BASE_DIR="$HOME"

WORKSPACE1="$BASE_DIR/workspace1"
WORKSPACE2="$BASE_DIR/workspace2"
WORKSPACE4="$BASE_DIR/workspace4"

REGISTRY_NAME="acme-registry"
REGISTRY_PORT="5000"
REGISTRY_IMAGE="docker.io/library/registry:latest"

# ============================================================
# COLORS
# ============================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================
# FUNCTIONS
# ============================================================

print_header()
{
    echo
    echo "============================================================"
    echo -e "${BLUE}$1${NC}"
    echo "============================================================"
    echo
}

success()
{
    echo -e "${GREEN}[OK]${NC} $1"
}

warning()
{
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error()
{
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================
# START
# ============================================================

print_header "ACME PODMAN EXAM ENVIRONMENT PREPARATION"

echo "Current user : $(whoami)"
echo "Home         : $HOME"
echo

# ============================================================
# CHECK PODMAN
# ============================================================

print_header "Checking Podman"

if ! command -v podman >/dev/null 2>&1
then

    error "Podman is not installed."

    echo
    echo "Please install Podman before running this script."
    echo

    exit 1

fi

success "Podman is available."

podman --version

# ============================================================
# CHECK CURL
# ============================================================

if ! command -v curl >/dev/null 2>&1
then

    error "curl is required to verify the local registry."

    exit 1

fi

success "curl is available."

# ============================================================
# DISPLAY HOME DIRECTORY
# ============================================================

print_header "Student Workspace"

echo "The personal workspace will be created under:"
echo
echo "    $HOME"
echo

# ============================================================
# CREATE WORKSPACE DIRECTORIES
# ============================================================

print_header "Creating Workspace Directories"

mkdir -p \
    "$WORKSPACE1/acme-nginx-html" \
    "$WORKSPACE2/acme-nginx-web/html" \
    "$WORKSPACE2/acme-nginx-web/conf" \
    "$WORKSPACE4/acme-mariadb-db/scripts"

success "Workspace directories created."

# ============================================================
# TASK 1
# RUNNING SIMPLE CONTAINERS
# ============================================================

print_header "Preparing Task 1"

cat > "$WORKSPACE1/acme-nginx-html/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <title>ACME NginX Demo</title>
</head>

<body>
    <h1>Hello World NginX</h1>
</body>

</html>
EOF

success "Task 1 index.html created."

# ============================================================
# TASK 2
# INTERACTING WITH CONTAINERS
# ============================================================

print_header "Preparing Task 2"

# ------------------------------------------------------------
# HTML
# ------------------------------------------------------------

cat > "$WORKSPACE2/acme-nginx-web/html/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <title>ACME NginX Container</title>
</head>

<body>
    <h1>ACME NginX Live Configuration</h1>
    <p>This page was copied into the running container.</p>
</body>

</html>
EOF

success "Task 2 HTML file created."

# ------------------------------------------------------------
# NGINX CONFIGURATION
# ------------------------------------------------------------

cat > "$WORKSPACE2/acme-nginx-web/conf/nginx.conf" <<'EOF'
server {

    listen 80;
    listen [::]:80;

    server_name localhost;

    root /usr/share/nginx/html;

    index index.html;

    location / {

        try_files $uri $uri/ =404;

    }

}
EOF

success "Task 2 Nginx configuration created."

# ============================================================
# TASK 4.1
# BUILDING CUSTOM MARIADB IMAGE
# ============================================================

print_header "Preparing Task 4.1"

cat > "$WORKSPACE4/acme-mariadb-containerfile" <<'EOF'
#add the rightcommands 
EOF

success "Task 4.1 Containerfile created."

# ============================================================
# TASK 4.2
# MARIADB EXPORT IMAGE
# ============================================================

print_header "Preparing Task 4.2"

cat > "$WORKSPACE4/acme-mariadb-db/acme-db-export-containerfile" <<'EOF'
#Add whatever is needed to perform the task.


RUN apt-get update \
    && apt-get install -y --no-install-recommends mariadb-client \
    && rm -rf /var/lib/apt/lists/*

EOF

success "Task 4.2 Containerfile created."

# ============================================================
# EXPORT SCRIPT
# ============================================================

cat > "$WORKSPACE4/acme-mariadb-db/scripts/export.sh" <<'EOF'
#!/bin/sh

echo "Starting MariaDB export..."

if mariadb-dump \
    -h "${MARIADB_HOST:-localhost}" \
    -u root \
    -p"$MARIADB_ROOT_PASSWORD" \
    "$MARIADB_DATABASE" > /home/acmeMpsql.sql
then

    echo "Export completed. File saved at /home/acmeMpsql.sql"

else

    echo "Export failed."

    rm -f /home/acmeMpsql.sql

    exit 1

fi
EOF

chmod +x "$WORKSPACE4/acme-mariadb-db/scripts/export.sh"

success "export.sh created and made executable."

# ============================================================
# FILE PERMISSIONS
# ============================================================

print_header "Setting File Permissions"

chmod 755 \
    "$WORKSPACE1" \
    "$WORKSPACE1/acme-nginx-html" \
    "$WORKSPACE2" \
    "$WORKSPACE2/acme-nginx-web" \
    "$WORKSPACE2/acme-nginx-web/html" \
    "$WORKSPACE2/acme-nginx-web/conf" \
    "$WORKSPACE4" \
    "$WORKSPACE4/acme-mariadb-db" \
    "$WORKSPACE4/acme-mariadb-db/scripts"

chmod 644 \
    "$WORKSPACE1/acme-nginx-html/index.html" \
    "$WORKSPACE2/acme-nginx-web/html/index.html" \
    "$WORKSPACE2/acme-nginx-web/conf/nginx.conf" \
    "$WORKSPACE4/acme-mariadb-containerfile" \
    "$WORKSPACE4/acme-mariadb-db/acme-db-export-containerfile"

chmod 755 \
    "$WORKSPACE4/acme-mariadb-db/scripts/export.sh"

success "Permissions configured."

# ============================================================
# VERIFY FILES
# ============================================================

print_header "Verifying Exam Files"

REQUIRED_FILES=(

    "$WORKSPACE1/acme-nginx-html/index.html"

    "$WORKSPACE2/acme-nginx-web/html/index.html"

    "$WORKSPACE2/acme-nginx-web/conf/nginx.conf"

    "$WORKSPACE4/acme-mariadb-containerfile"

    "$WORKSPACE4/acme-mariadb-db/acme-db-export-containerfile"

    "$WORKSPACE4/acme-mariadb-db/scripts/export.sh"

)

for FILE in "${REQUIRED_FILES[@]}"
do

    if [[ -f "$FILE" ]]
    then

        success "$FILE"

    else

        error "Missing file: $FILE"

        exit 1

    fi

done


# ============================================================
# DISPLAY FINAL DIRECTORY STRUCTURE
# ============================================================

print_header "Exam Workspace"

echo "$HOME"
echo

if command -v tree >/dev/null 2>&1
then

    tree \
        "$WORKSPACE1" \
        "$WORKSPACE2" \
        "$WORKSPACE4"

else

    find \
        "$WORKSPACE1" \
        "$WORKSPACE2" \
        "$WORKSPACE4" \
        -type f | sort

fi

# ============================================================
# FINAL INFORMATION
# ============================================================

print_header "ENVIRONMENT READY"

echo "Current user:"
echo
echo "    $(whoami)"
echo

echo "Personal home directory:"
echo
echo "    $HOME"
echo

echo "Student workspaces:"
echo
echo "    $HOME/workspace1"
echo "    $HOME/workspace2"
echo "    $HOME/workspace4"
echo

echo "Local registry:"
echo
echo "    localhost:5000"
echo

echo "The following have NOT been performed:"
echo
echo "    - No exam images were pulled"
echo "    - No exam containers were created"
echo "    - No exam networks were created"
echo "    - No exam volumes were created"
echo "    - No Podman Compose check was performed"
echo

echo "Students are responsible for performing those tasks"
echo "during the examination."
echo

echo "============================================================"
echo -e "${GREEN}Preparation completed successfully.${NC}"
echo "============================================================"
echo

