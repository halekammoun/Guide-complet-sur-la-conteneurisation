#!/bin/bash

# ============================================================
# ACME CORPORATION - PODMAN EXAM GRADER
# ============================================================
#
# Maximum Mark : 300
# Pass Mark    : 210
#
# Tasks:
#   1. Running Simple Containers             30 marks
#   2. Interacting with Containers           45 marks
#   3. Injecting Variables                   45 marks
#   4. Building Custom Images                65 marks
#   5. Multi-Container Deployment            75 marks
#   6. Troubleshooting Multi-Container      40 marks
#
# Total                                      300 marks
#
# ============================================================

set -u

# ============================================================
# CONFIGURATION
# ============================================================

MAX_MARK=300
PASS_MARK=210

# ------------------------------------------------------------
# PUT YOUR REAL TELEGRAM VALUES HERE
# ------------------------------------------------------------

TELEGRAM_BOT_TOKEN="8346247004:AAE6iGSSexmDtMLZwgT56J-C7tAhFHkMkA4"
TELEGRAM_CHAT_ID="8931835145"

# ============================================================
# COLORS
# ============================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================
# OUTPUT FUNCTIONS
# ============================================================

ok()
{
    echo -e "${GREEN}[OK]${NC} $1"
}

fail()
{
    echo -e "${RED}[FAIL]${NC} $1"
}

warn()
{
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info()
{
    echo -e "${BLUE}[INFO]${NC} $1"
}

# ============================================================
# STUDENT INFORMATION
# ============================================================

clear

echo ""
echo "============================================================"
echo "             ACME CORPORATION PODMAN EXAM"
echo "                    GRADING SYSTEM"
echo "============================================================"
echo ""

read -rp "Enter your full name: " STUDENT_NAME
read -rp "Enter your email address: " STUDENT_EMAIL

# Remove Markdown mailto formatting if pasted accidentally.
STUDENT_EMAIL="${STUDENT_EMAIL#\[}"
STUDENT_EMAIL="${STUDENT_EMAIL%%\](mailto:*}"
STUDENT_EMAIL="${STUDENT_EMAIL%%)*}"

# Remove surrounding spaces.
STUDENT_NAME="$(echo "$STUDENT_NAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
STUDENT_EMAIL="$(echo "$STUDENT_EMAIL" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

[[ -z "$STUDENT_NAME" ]] && STUDENT_NAME="Unknown Student"
[[ -z "$STUDENT_EMAIL" ]] && STUDENT_EMAIL="Not provided"

# IMPORTANT:
# Define these BEFORE anything uses them.
STUDENT_USER="$(id -un)"
STUDENT_HOME="$HOME"

DATE_NOW="$(date '+%a %b %d %I:%M:%S %p %Z %Y')"

echo ""
echo "Student Name  : $STUDENT_NAME"
echo "Student Email : $STUDENT_EMAIL"
echo "Linux User    : $STUDENT_USER"
echo "Student Home  : $STUDENT_HOME"
echo ""

# ============================================================
# REPORT
# ============================================================

REPORT_DIR="$STUDENT_HOME/grading-reports"
mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
REPORT="$REPORT_DIR/grade-$TIMESTAMP.txt"

TOTAL=0

# Task scores
T1=0
T2=0
T3=0
T4=0
T5=0
T6=0

# ============================================================
# REPORT FUNCTIONS
# ============================================================

log()
{
    echo "$1" | tee -a "$REPORT"
}

# ============================================================
# INITIAL REPORT
# ============================================================

log "============================================================"
log "        ACME CORPORATION - PODMAN EXAM GRADING"
log "============================================================"
log "Date          : $DATE_NOW"
log "Student Name  : $STUDENT_NAME"
log "Student Email : $STUDENT_EMAIL"
log "Linux User    : $STUDENT_USER"
log "Student Home  : $STUDENT_HOME"
log "Maximum Mark  : $MAX_MARK"
log "Passing Mark  : $PASS_MARK"
log "============================================================"
log ""

# ============================================================
# PODMAN CHECK
# ============================================================

if ! command -v podman >/dev/null 2>&1; then
    fail "Podman is not installed or not available"
    log "[FATAL] Podman is not available."
    exit 1
fi

ok "Podman is available"
log "[OK] Podman is available"
log ""

# ============================================================
# HELPER FUNCTIONS
# ============================================================

container_exists()
{
    podman container exists "$1" 2>/dev/null
}

container_running()
{
    [[ "$(podman inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]
}

image_exists()
{
    podman image exists "$1" 2>/dev/null
}

network_exists()
{
    podman network exists "$1" 2>/dev/null
}

volume_exists()
{
    podman volume exists "$1" 2>/dev/null
}

get_env()
{
    local container="$1"
    local variable="$2"

    podman inspect \
        -f '{{range .Config.Env}}{{println .}}{{end}}' \
        "$container" 2>/dev/null |
        sed -n "s/^${variable}=//p" |
        head -n 1
}

has_mount()
{
    local container="$1"
    local source="$2"
    local destination="$3"
    local name src dst

    # Fields are pipe-delimited. Bind mounts always have an empty .Name, and
    # bash's `read` treats TAB as "IFS whitespace" -- meaning a leading empty
    # tab-delimited field gets silently stripped, shifting every field left
    # by one (name absorbs the source path, src absorbs the destination, dst
    # ends up empty). Using "|" avoids that stripping so empty fields are
    # preserved. For named volumes Podman reports .Source as the resolved
    # host storage path, not the volume name -- so we accept a match against
    # EITHER the volume .Name (for -v volname:/dest mounts) OR the .Source
    # path (for -v /host/path:/dest bind mounts).
    while IFS='|' read -r name src dst; do
        if [[ "$dst" == "$destination" ]] &&
           [[ "$name" == "$source" || "$src" == "$source" ]]; then
            return 0
        fi
    done < <(podman inspect \
        -f '{{range .Mounts}}{{printf "%s|%s|%s\n" .Name .Source .Destination}}{{end}}' \
        "$container" 2>/dev/null)

    return 1
}

has_network()
{
    local container="$1"
    local network="$2"

    podman inspect \
        -f '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' \
        "$container" 2>/dev/null |
        grep -Fxq "$network"
}

has_port_mapping()
{
    local container="$1"
    local host_port="$2"
    local container_port="$3"

    podman port "$container" 2>/dev/null |
        grep -Eq "(^|:)${container_port}.*${host_port}"
}

# The exam's own solution for Task 2 uses `podman cp` into an already
# running container -- not a `-v` bind mount. `podman cp` leaves no trace
# in `podman inspect .Mounts`, so has_mount() alone can't see it. These two
# helpers instead check the container's actual filesystem via `podman exec`,
# which reflects the result of EITHER approach (bind mount or cp) equally.

# True if every entry in host_dir also exists (by name) inside the
# container at dest_dir.
dir_contents_present()
{
    local container="$1"
    local host_dir="$2"
    local dest_dir="$3"

    [[ -d "$host_dir" ]] || return 1

    local host_listing
    host_listing="$(find "$host_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort)"
    [[ -z "$host_listing" ]] && return 1

    local container_listing
    container_listing="$(podman exec "$container" sh -c "ls -1A '$dest_dir'" 2>/dev/null | sort)"
    [[ -z "$container_listing" ]] && return 1

    local f
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        grep -Fxq "$f" <<< "$container_listing" || return 1
    done <<< "$host_listing"

    return 0
}

# True if dest_file inside the container has the same content as host_file.
file_contents_match()
{
    local container="$1"
    local host_file="$2"
    local dest_file="$3"

    [[ -f "$host_file" ]] || return 1

    local host_sum container_sum
    host_sum="$(sha256sum "$host_file" 2>/dev/null | awk '{print $1}')"
    [[ -z "$host_sum" ]] && return 1

    container_sum="$(podman exec "$container" sh -c "sha256sum '$dest_file' 2>/dev/null" | awk '{print $1}')"
    [[ -n "$container_sum" && "$host_sum" == "$container_sum" ]]
}

# ============================================================
# TASK 1
# RUNNING SIMPLE CONTAINERS
# 30 MARKS
# ============================================================

echo ""
echo "============================================================"
echo " TASK 1 - RUNNING SIMPLE CONTAINERS"
echo "============================================================"

log ""
log "============================================================"
log "TASK 1 - RUNNING SIMPLE CONTAINERS"
log "============================================================"

T1=0

# 1. Container exists - 5
if container_exists "acme-demo-html"; then
    ok "acme-demo-html exists"
    log "[OK] acme-demo-html exists"
    T1=$((T1 + 5))
else
    fail "acme-demo-html does not exist"
    log "[FAIL] acme-demo-html does not exist"
fi

# 2. Container running - 5
if container_running "acme-demo-html"; then
    ok "acme-demo-html is running"
    log "[OK] acme-demo-html is running"
    T1=$((T1 + 5))
else
    fail "acme-demo-html is not running"
    log "[FAIL] acme-demo-html is not running"
fi

# 3. Image - 5
if container_exists "acme-demo-html"; then
    IMAGE="$(podman inspect -f '{{.Config.Image}}' acme-demo-html 2>/dev/null)"

    if [[ "$IMAGE" == "docker.io/library/nginx:latest" ||
          "$IMAGE" == "docker.io/library/nginx" ||
          "$IMAGE" == "nginx:latest" ||
          "$IMAGE" == "nginx" ]]; then
        ok "Correct nginx image"
        log "[OK] Correct nginx image: $IMAGE"
        T1=$((T1 + 5))
    else
        fail "Incorrect image: $IMAGE"
        log "[FAIL] Incorrect image: $IMAGE"
    fi
fi

# 4. Port 8001:80 - 5
if container_exists "acme-demo-html" &&
   has_port_mapping "acme-demo-html" "8001" "80"; then
    ok "Port 8001:80 is configured"
    log "[OK] Port 8001:80 configured"
    T1=$((T1 + 5))
else
    fail "Port 8001:80 is not configured"
    log "[FAIL] Port 8001:80 is not configured"
fi

# 5. HTML directory mounted - 5
if container_exists "acme-demo-html" &&
   has_mount \
       "acme-demo-html" \
       "$STUDENT_HOME/workspace1/acme-nginx-html" \
       "/usr/share/nginx/html"; then
    ok "HTML directory is mounted correctly"
    log "[OK] HTML directory mounted"
    T1=$((T1 + 5))
else
    fail "HTML directory is not mounted correctly"
    log "[FAIL] HTML directory mount incorrect"
fi

# 6. HTTP response - 5
RESPONSE="$(curl -s --max-time 5 http://localhost:8001 2>/dev/null || true)"

if echo "$RESPONSE" | grep -Fq "Hello World NginX"; then
    ok "Task 1 HTTP response is correct"
    log "[OK] http://localhost:8001 returns Hello World NginX"
    T1=$((T1 + 5))
else
    fail "Task 1 HTTP response is incorrect"
    log "[FAIL] http://localhost:8001 response incorrect"
fi

(( T1 > 30 )) && T1=30

log "Task 1 Score: $T1/30"
echo "Task 1 Score: $T1/30"

# ============================================================
# TASK 2
# INTERACTING WITH CONTAINERS
# 45 MARKS
# ============================================================

echo ""
echo "============================================================"
echo " TASK 2 - INTERACTING WITH CONTAINERS"
echo "============================================================"

log ""
log "============================================================"
log "TASK 2 - INTERACTING WITH CONTAINERS"
log "============================================================"

T2=0

# 1. Container exists - 5
if container_exists "acme-demo-nginx"; then
    ok "acme-demo-nginx exists"
    log "[OK] acme-demo-nginx exists"
    T2=$((T2 + 5))
else
    fail "acme-demo-nginx does not exist"
    log "[FAIL] acme-demo-nginx does not exist"
fi

# 2. Running - 5
if container_running "acme-demo-nginx"; then
    ok "acme-demo-nginx is running"
    log "[OK] acme-demo-nginx is running"
    T2=$((T2 + 5))
else
    fail "acme-demo-nginx is not running"
    log "[FAIL] acme-demo-nginx is not running"
fi

# 3. Correct image - 5
if container_exists "acme-demo-nginx"; then
    IMAGE="$(podman inspect -f '{{.Config.Image}}' acme-demo-nginx 2>/dev/null)"

    if [[ "$IMAGE" == "docker.io/library/nginx:latest" ||
          "$IMAGE" == "docker.io/library/nginx" ||
          "$IMAGE" == "nginx:latest" ||
          "$IMAGE" == "nginx" ]]; then
        ok "Correct nginx image"
        log "[OK] Correct nginx image"
        T2=$((T2 + 5))
    else
        fail "Incorrect image"
        log "[FAIL] Incorrect image: $IMAGE"
    fi
fi

# 4. Port 8002:80 - 5
if container_exists "acme-demo-nginx" &&
   has_port_mapping "acme-demo-nginx" "8002" "80"; then
    ok "Port 8002:80 configured"
    log "[OK] Port 8002:80 configured"
    T2=$((T2 + 5))
else
    fail "Port 8002:80 missing"
    log "[FAIL] Port 8002:80 missing"
fi

# 5. HTML directory copied/mounted - 10
# Accepts either approach: `podman run -v ...` (bind mount) or the exam's
# own solution using `podman cp` into a running container.
if container_exists "acme-demo-nginx" &&
   { has_mount \
       "acme-demo-nginx" \
       "$STUDENT_HOME/workspace2/acme-nginx-web/html" \
       "/usr/share/nginx/html" ||
     dir_contents_present \
       "acme-demo-nginx" \
       "$STUDENT_HOME/workspace2/acme-nginx-web/html" \
       "/usr/share/nginx/html"; }; then
    ok "HTML directory present (mount or copy)"
    log "[OK] HTML directory present (mount or copy)"
    T2=$((T2 + 10))
else
    fail "HTML directory not mounted or copied"
    log "[FAIL] HTML directory not mounted or copied"
fi

# 6. Config copied/mounted + running - 10
# Accepts either approach: `podman run -v ...` (bind mount) or the exam's
# own solution using `podman cp` into a running container.
if container_exists "acme-demo-nginx" &&
   { has_mount \
       "acme-demo-nginx" \
       "$STUDENT_HOME/workspace2/acme-nginx-web/conf/nginx.conf" \
       "/etc/nginx/conf.d/default.conf" ||
     file_contents_match \
       "acme-demo-nginx" \
       "$STUDENT_HOME/workspace2/acme-nginx-web/conf/nginx.conf" \
       "/etc/nginx/conf.d/default.conf"; }; then

    ok "Nginx configuration present (mount or copy)"
    log "[OK] Nginx configuration present (mount or copy)"

    if container_running "acme-demo-nginx"; then
        ok "Nginx container persists after configuration"
        log "[OK] Nginx container persists"
        T2=$((T2 + 10))
    else
        fail "Nginx container is not running"
        log "[FAIL] Nginx container not running"
    fi
else
    fail "Nginx configuration not mounted or copied"
    log "[FAIL] Nginx configuration not mounted or copied"
fi

# 7. HTTP - confirms the copied config + reload actually worked - 5
RESPONSE="$(curl -s --max-time 5 http://localhost:8002 2>/dev/null || true)"

if [[ -n "$RESPONSE" ]]; then
    ok "Port 8002 responds"
    log "[OK] http://localhost:8002 responds"
    T2=$((T2 + 5))
else
    fail "Port 8002 does not respond"
    log "[FAIL] http://localhost:8002 does not respond"
fi

(( T2 > 45 )) && T2=45

log "Task 2 Score: $T2/45"
echo "Task 2 Score: $T2/45"

# ============================================================
# TASK 3
# INJECTING VARIABLES
# 45 MARKS
# ============================================================

echo ""
echo "============================================================"
echo " TASK 3 - INJECTING VARIABLES"
echo "============================================================"

log ""
log "============================================================"
log "TASK 3 - INJECTING VARIABLES"
log "============================================================"

T3=0

C1="acme_nginx_container_1"
C2="acme_nginx_container_2"

# 1. Container 1 exists - 5
if container_exists "$C1"; then
    ok "$C1 exists"
    log "[OK] $C1 exists"
    T3=$((T3 + 5))
else
    fail "$C1 does not exist"
    log "[FAIL] $C1 does not exist"
fi

# 2. Container 2 exists - 5
if container_exists "$C2"; then
    ok "$C2 exists"
    log "[OK] $C2 exists"
    T3=$((T3 + 5))
else
    fail "$C2 does not exist"
    log "[FAIL] $C2 does not exist"
fi

# 3. Container 1 environment - 10
if container_exists "$C1"; then
    ENV1="$(get_env "$C1" "RESPONSE")"

    if [[ "$ENV1" == "Welcome_ACME_Nginx_Container_1" ]]; then
        ok "$C1 RESPONSE is correct"
        log "[OK] $C1 RESPONSE=$ENV1"
        T3=$((T3 + 10))
    else
        fail "$C1 RESPONSE is incorrect"
        log "[FAIL] $C1 RESPONSE=$ENV1"
    fi
fi

# 4. Container 2 environment - 10
if container_exists "$C2"; then
    ENV2="$(get_env "$C2" "RESPONSE")"

    if [[ "$ENV2" == "Welcome_ACME_Nginx_Container_2" ]]; then
        ok "$C2 RESPONSE is correct"
        log "[OK] $C2 RESPONSE=$ENV2"
        T3=$((T3 + 10))
    else
        fail "$C2 RESPONSE is incorrect"
        log "[FAIL] $C2 RESPONSE=$ENV2"
    fi
fi

# 5. Port 8003:8080 - 15
# NOTE: only one container can hold host port 8003 at a time by design (the
# exam requires them to coexist but not run simultaneously), so this check
# is inherently mutually exclusive -- exactly one branch can ever award
# points. It's weighted higher than the other items so a fully-correct
# submission (both containers built correctly, one currently holding the
# port) can still reach the full 45/45.
if container_exists "$C1" &&
   has_port_mapping "$C1" "8003" "8080"; then
    ok "$C1 has port 8003:8080"
    log "[OK] $C1 port mapping correct"
    T3=$((T3 + 15))
elif container_exists "$C2" &&
     has_port_mapping "$C2" "8003" "8080"; then
    ok "$C2 has port 8003:8080"
    log "[OK] $C2 port mapping correct"
    T3=$((T3 + 15))
else
    fail "No correct 8003:8080 mapping found"
    log "[FAIL] Port 8003:8080 not found"
fi

(( T3 > 45 )) && T3=45

log "Task 3 Score: $T3/45"
echo "Task 3 Score: $T3/45"

# ============================================================
# TASK 4
# BUILDING CUSTOM CONTAINER IMAGES
# 65 MARKS
# ============================================================

echo ""
echo "============================================================"
echo " TASK 4 - BUILDING CUSTOM CONTAINER IMAGES"
echo "============================================================"

log ""
log "============================================================"
log "TASK 4 - BUILDING CUSTOM CONTAINER IMAGES"
log "============================================================"

T4=0

# ------------------------------------------------------------
# 4.1 Custom MariaDB image
# ------------------------------------------------------------

# 1. Image exists with required tag - 10
if image_exists "acme:5000/acme-mariadb:latest"; then
    ok "acme:5000/acme-mariadb:latest exists"
    log "[OK] acme:5000/acme-mariadb:latest exists"
    T4=$((T4 + 10))
else
    fail "acme:5000/acme-mariadb:latest missing"
    log "[FAIL] acme:5000/acme-mariadb:latest missing"
fi

# 2. Local acme-mariadb image - 5
if image_exists "acme-mariadb:latest"; then
    ok "acme-mariadb:latest exists"
    log "[OK] acme-mariadb:latest exists"
    T4=$((T4 + 5))
else
    fail "acme-mariadb:latest missing"
    log "[FAIL] acme-mariadb:latest missing"
fi

# 3. Containerfile - 10
CONTAINERFILE="$STUDENT_HOME/workspace4/acme-mariadb-containerfile"

if [[ -f "$CONTAINERFILE" ]]; then
    ok "MariaDB Containerfile exists"
    log "[OK] $CONTAINERFILE exists"

    CF_CONTENT="$(cat "$CONTAINERFILE")"

    if echo "$CF_CONTENT" | grep -Eq 'FROM[[:space:]]+.*mariadb'; then
        ok "MariaDB base image declared"
        log "[OK] MariaDB base image declared"
        T4=$((T4 + 5))
    else
        fail "MariaDB base image missing"
        log "[FAIL] MariaDB base image missing"
    fi

    if echo "$CF_CONTENT" | grep -Eq 'ARG[[:space:]]+ACME_MARIADB_DATABASE'; then
        ok "ACME_MARIADB_DATABASE argument found"
        log "[OK] ACME_MARIADB_DATABASE ARG found"
        T4=$((T4 + 5))
    else
        fail "ACME_MARIADB_DATABASE argument missing"
        log "[FAIL] ACME_MARIADB_DATABASE ARG missing"
    fi

    if echo "$CF_CONTENT" | grep -Eq 'ARG[[:space:]]+ACME_MARIADB_PASSWORD'; then
        ok "ACME_MARIADB_PASSWORD argument found"
        log "[OK] ACME_MARIADB_PASSWORD ARG found"
        T4=$((T4 + 10))
    else
        fail "ACME_MARIADB_PASSWORD argument missing"
        log "[FAIL] ACME_MARIADB_PASSWORD ARG missing"
    fi
else
    fail "MariaDB Containerfile missing"
    log "[FAIL] MariaDB Containerfile missing"
fi

# ------------------------------------------------------------
# 4.2 Export image
# ------------------------------------------------------------

# 5. Local export image - 10
# NOTE: the exam requirements (7.2.1) only ask for the image to be tagged
# "acme-mariadb-export:latest". Tagging/pushing it into a registry
# (acme:5000/...) is an optional extra step shown in the solution write-up,
# not an actual requirement, so it is no longer graded here.
if image_exists "acme-mariadb-export:latest"; then
    ok "Local export image exists"
    log "[OK] acme-mariadb-export:latest exists"
    T4=$((T4 + 10))
else
    fail "Local export image missing"
    log "[FAIL] acme-mariadb-export:latest missing"
fi

# 6. Export Containerfile - 10
EXPORT_CF="$STUDENT_HOME/workspace4/acme-mariadb-db/acme-db-export-containerfile"

if [[ -f "$EXPORT_CF" ]]; then
    ok "Export Containerfile exists"
    log "[OK] Export Containerfile exists"

    EXPORT_CONTENT="$(cat "$EXPORT_CF")"

    if echo "$EXPORT_CONTENT" | grep -Eq 'WORKDIR[[:space:]]+/scripts'; then
        ok "WORKDIR /scripts found"
        log "[OK] WORKDIR /scripts"
        T4=$((T4 + 5))
    else
        fail "WORKDIR /scripts missing"
        log "[FAIL] WORKDIR /scripts missing"
    fi

    if echo "$EXPORT_CONTENT" | grep -Eq 'COPY[[:space:]].*scripts/export\.sh'; then
        ok "export.sh COPY instruction found"
        log "[OK] export.sh copied"
        T4=$((T4 + 5))
    else
        fail "export.sh COPY instruction missing"
        log "[FAIL] export.sh COPY missing"
    fi
else
    fail "Export Containerfile missing"
    log "[FAIL] Export Containerfile missing"
fi

# 7. Export script present on host - 5
EXPORT_SCRIPT="$STUDENT_HOME/workspace4/acme-mariadb-db/scripts/export.sh"

if [[ -f "$EXPORT_SCRIPT" ]]; then
    ok "export.sh exists"
    log "[OK] export.sh exists"
    T4=$((T4 + 5))
else
    fail "export.sh missing"
    log "[FAIL] export.sh missing"
fi

# 8. Functional check: mariadb client tools actually present - 5
# Mirrors the exam's own verification command (7.2.2).
if image_exists "acme-mariadb-export:latest"; then
    if podman run --rm --entrypoint sh acme-mariadb-export:latest \
        -c 'command -v mariadb-dump' >/dev/null 2>&1; then
        ok "mariadb-dump is available in the export image"
        log "[OK] mariadb-dump present in acme-mariadb-export:latest"
        T4=$((T4 + 5))
    else
        fail "mariadb-dump is not available in the export image"
        log "[FAIL] mariadb-dump missing from acme-mariadb-export:latest"
    fi
else
    fail "Cannot verify mariadb-dump: export image missing"
    log "[FAIL] mariadb-dump check skipped, image missing"
fi

(( T4 > 65 )) && T4=65

log "Task 4 Score: $T4/65"
echo "Task 4 Score: $T4/65"

# ============================================================
# TASK 5
# MULTI-CONTAINER DEPLOYMENT
# 75 MARKS
# ============================================================

echo ""
echo "============================================================"
echo " TASK 5 - MULTI-CONTAINER DEPLOYMENT"
echo "============================================================"

log ""
log "============================================================"
log "TASK 5 - MULTI-CONTAINER DEPLOYMENT"
log "============================================================"

T5=0

NETWORK="acme-wp-net"

# 1. Network - 5
if network_exists "$NETWORK"; then
    ok "$NETWORK exists"
    log "[OK] $NETWORK exists"
    T5=$((T5 + 5))
else
    fail "$NETWORK does not exist"
    log "[FAIL] $NETWORK does not exist"
fi

# 2. Volume acme-wp-backend - 3
if volume_exists "acme-wp-backend"; then
    ok "Volume acme-wp-backend exists"
    log "[OK] Volume acme-wp-backend exists"
    T5=$((T5 + 3))
else
    fail "Volume acme-wp-backend missing"
    log "[FAIL] Volume acme-wp-backend missing"
fi

# 3. Volume acme-wp-app - 3
if volume_exists "acme-wp-app"; then
    ok "Volume acme-wp-app exists"
    log "[OK] Volume acme-wp-app exists"
    T5=$((T5 + 3))
else
    fail "Volume acme-wp-app missing"
    log "[FAIL] Volume acme-wp-app missing"
fi

# 4. Volume acme_wordpress_data - 3
if volume_exists "acme_wordpress_data"; then
    ok "Volume acme_wordpress_data exists"
    log "[OK] Volume acme_wordpress_data exists"
    T5=$((T5 + 3))
else
    fail "Volume acme_wordpress_data missing"
    log "[FAIL] Volume acme_wordpress_data missing"
fi

# ------------------------------------------------------------
# MariaDB (20)
# ------------------------------------------------------------

if container_exists "mariadb"; then

    ok "mariadb container exists"
    log "[OK] mariadb exists"
    T5=$((T5 + 3))

    if container_running "mariadb"; then
        ok "mariadb is running"
        log "[OK] mariadb is running"
        T5=$((T5 + 3))
    else
        fail "mariadb is not running"
        log "[FAIL] mariadb is not running"
    fi

    if has_network "mariadb" "$NETWORK"; then
        ok "mariadb attached to $NETWORK"
        log "[OK] mariadb network correct"
        T5=$((T5 + 3))
    else
        fail "mariadb not attached to $NETWORK"
        log "[FAIL] mariadb network incorrect"
    fi

    if has_mount \
        "mariadb" \
        "acme-wp-backend" \
        "/bitnami/mariadb"; then
        ok "MariaDB volume mapping correct"
        log "[OK] acme-wp-backend:/bitnami/mariadb"
        T5=$((T5 + 5))
    else
        fail "MariaDB volume mapping incorrect"
        log "[FAIL] MariaDB volume mapping incorrect"
    fi

    if [[ "$(get_env mariadb MARIADB_USER)" == "acme_wordpress" &&
          "$(get_env mariadb MARIADB_PASSWORD)" == "acme" &&
          "$(get_env mariadb MARIADB_DATABASE)" == "acme_wordpress" &&
          "$(get_env mariadb MARIADB_ROOT_PASSWORD)" == "acme" ]]; then
        ok "MariaDB environment variables correct"
        log "[OK] MariaDB environment variables correct"
        T5=$((T5 + 6))
    else
        fail "MariaDB environment variables incorrect"
        log "[FAIL] MariaDB environment variables incorrect"
    fi

else
    fail "mariadb container missing"
    log "[FAIL] mariadb container missing"
fi

# ------------------------------------------------------------
# Nginx (18)
# ------------------------------------------------------------

if container_exists "acme-wp-app"; then

    ok "acme-wp-app exists"
    log "[OK] acme-wp-app exists"
    T5=$((T5 + 3))

    if container_running "acme-wp-app"; then
        ok "acme-wp-app is running"
        log "[OK] acme-wp-app is running"
        T5=$((T5 + 3))
    else
        fail "acme-wp-app is not running"
        log "[FAIL] acme-wp-app not running"
    fi

    if has_network "acme-wp-app" "$NETWORK"; then
        ok "acme-wp-app attached to network"
        log "[OK] acme-wp-app network correct"
        T5=$((T5 + 3))
    else
        fail "acme-wp-app network incorrect"
        log "[FAIL] acme-wp-app network incorrect"
    fi

    if has_mount \
        "acme-wp-app" \
        "acme-wp-app" \
        "/etc/nginx"; then
        ok "Nginx volume mapping correct"
        log "[OK] acme-wp-app:/etc/nginx"
        T5=$((T5 + 4))
    else
        fail "Nginx volume mapping incorrect"
        log "[FAIL] Nginx volume mapping incorrect"
    fi

    if has_port_mapping "acme-wp-app" "8080" "8080"; then
        ok "Nginx port 8080:8080 correct"
        log "[OK] Nginx port mapping correct"
        T5=$((T5 + 5))
    else
        fail "Nginx port 8080:8080 missing"
        log "[FAIL] Nginx port mapping missing"
    fi

else
    fail "acme-wp-app missing"
    log "[FAIL] acme-wp-app missing"
fi

# ------------------------------------------------------------
# WordPress (23)
# ------------------------------------------------------------

if container_exists "acme-wordpress"; then

    ok "acme-wordpress exists"
    log "[OK] acme-wordpress exists"
    T5=$((T5 + 3))

    if container_running "acme-wordpress"; then
        ok "acme-wordpress is running"
        log "[OK] acme-wordpress is running"
        T5=$((T5 + 3))
    else
        fail "acme-wordpress is not running"
        log "[FAIL] acme-wordpress not running"
    fi

    if has_network "acme-wordpress" "$NETWORK"; then
        ok "acme-wordpress attached to network"
        log "[OK] WordPress network correct"
        T5=$((T5 + 3))
    else
        fail "acme-wordpress network incorrect"
        log "[FAIL] WordPress network incorrect"
    fi

    if has_mount \
        "acme-wordpress" \
        "acme_wordpress_data" \
        "/bitnami/wordpress"; then
        ok "WordPress volume mapping correct"
        log "[OK] acme_wordpress_data:/bitnami/wordpress"
        T5=$((T5 + 4))
    else
        fail "WordPress volume mapping incorrect"
        log "[FAIL] WordPress volume mapping incorrect"
    fi

    if [[ "$(get_env acme-wordpress WORDPRESS_DATABASE_USER)" == "acme_wordpress" &&
          "$(get_env acme-wordpress WORDPRESS_DATABASE_PASSWORD)" == "acme" &&
          "$(get_env acme-wordpress WORDPRESS_DATABASE_NAME)" == "acme_wordpress" ]]; then
        ok "WordPress environment variables correct"
        log "[OK] WordPress environment variables correct"
        T5=$((T5 + 5))
    else
        fail "WordPress environment variables incorrect"
        log "[FAIL] WordPress environment variables incorrect"
    fi

    if has_port_mapping "acme-wordpress" "8004" "8080"; then
        ok "WordPress 8004:8080 mapping correct"
        log "[OK] WordPress 8004:8080 correct"
        T5=$((T5 + 3))
    else
        fail "WordPress 8004:8080 mapping missing"
        log "[FAIL] WordPress 8004:8080 missing"
    fi

    if has_port_mapping "acme-wordpress" "8443" "8443"; then
        ok "WordPress 8443:8443 mapping correct"
        log "[OK] WordPress 8443:8443 correct"
        T5=$((T5 + 2))
    else
        fail "WordPress 8443:8443 mapping missing"
        log "[FAIL] WordPress 8443:8443 missing"
    fi

else
    fail "acme-wordpress missing"
    log "[FAIL] acme-wordpress missing"
fi

# Website test
WP_RESPONSE="$(curl -k -s --max-time 8 https://localhost:8443 2>/dev/null || true)"

if [[ -n "$WP_RESPONSE" ]]; then
    ok "WordPress HTTPS endpoint responds"
    log "[OK] https://localhost:8443 responds"
else
    warn "WordPress HTTPS endpoint does not respond"
    log "[WARN] https://localhost:8443 does not respond"
fi

(( T5 > 75 )) && T5=75

log "Task 5 Score: $T5/75"
echo "Task 5 Score: $T5/75"

# ============================================================
# TASK 6
# TROUBLESHOOTING MULTI-CONTAINER STACK
# 40 MARKS
# ============================================================

echo ""
echo "============================================================"
echo " TASK 6 - TROUBLESHOOTING MULTI-CONTAINER STACK"
echo "============================================================"

log ""
log "============================================================"
log "TASK 6 - TROUBLESHOOTING MULTI-CONTAINER STACK"
log "============================================================"

T6=0

TS_NETWORK="sks-wp-ts"
TS_BACKEND="sks-backend-ts-vol"
TS_APP="sks-wp-app-ts-vol"

# 1. Network - 5
if network_exists "$TS_NETWORK"; then
    ok "$TS_NETWORK exists"
    log "[OK] $TS_NETWORK exists"
    T6=$((T6 + 5))
else
    fail "$TS_NETWORK missing"
    log "[FAIL] $TS_NETWORK missing"
fi

# 2. Backend volume - 5
if volume_exists "$TS_BACKEND"; then
    ok "$TS_BACKEND exists"
    log "[OK] $TS_BACKEND exists"
    T6=$((T6 + 5))
else
    fail "$TS_BACKEND missing"
    log "[FAIL] $TS_BACKEND missing"
fi

# 3. App volume - 5
if volume_exists "$TS_APP"; then
    ok "$TS_APP exists"
    log "[OK] $TS_APP exists"
    T6=$((T6 + 5))
else
    fail "$TS_APP missing"
    log "[FAIL] $TS_APP missing"
fi

# 4. Backend container - 5
if container_exists "sks-backend-ts"; then
    ok "sks-backend-ts exists"
    log "[OK] sks-backend-ts exists"

    if container_running "sks-backend-ts"; then
        ok "sks-backend-ts is running"
        log "[OK] sks-backend-ts running"
        T6=$((T6 + 5))
    else
        fail "sks-backend-ts is not running"
        log "[FAIL] sks-backend-ts not running"
    fi
else
    fail "sks-backend-ts missing"
    log "[FAIL] sks-backend-ts missing"
fi

# 5. WordPress application - 5
if container_exists "sks-wp-app-ts"; then
    ok "sks-wp-app-ts exists"
    log "[OK] sks-wp-app-ts exists"

    if container_running "sks-wp-app-ts"; then
        ok "sks-wp-app-ts is running"
        log "[OK] sks-wp-app-ts running"
        T6=$((T6 + 5))
    else
        fail "sks-wp-app-ts not running"
        log "[FAIL] sks-wp-app-ts not running"
    fi
else
    fail "sks-wp-app-ts missing"
    log "[FAIL] sks-wp-app-ts missing"
fi

# 6. Frontend - 5
if container_exists "sks-frontend-ts"; then
    ok "sks-frontend-ts exists"
    log "[OK] sks-frontend-ts exists"

    if container_running "sks-frontend-ts"; then
        ok "sks-frontend-ts is running"
        log "[OK] sks-frontend-ts running"
        T6=$((T6 + 5))
    else
        fail "sks-frontend-ts not running"
        log "[FAIL] sks-frontend-ts not running"
    fi
else
    fail "sks-frontend-ts missing"
    log "[FAIL] sks-frontend-ts missing"
fi

# 7. All containers on network - 5
NETWORK_OK=0

for C in sks-backend-ts sks-wp-app-ts sks-frontend-ts; do
    if container_exists "$C" && has_network "$C" "$TS_NETWORK"; then
        NETWORK_OK=$((NETWORK_OK + 1))
    fi
done

if [[ "$NETWORK_OK" -eq 3 ]]; then
    ok "All Task 6 containers are attached to $TS_NETWORK"
    log "[OK] All three containers use $TS_NETWORK"
    T6=$((T6 + 5))
else
    fail "Not all Task 6 containers use $TS_NETWORK"
    log "[FAIL] Only $NETWORK_OK/3 containers use $TS_NETWORK"
fi

# 8. Frontend port 8084:80 - 5
if container_exists "sks-frontend-ts" &&
   has_port_mapping "sks-frontend-ts" "8084" "80"; then
    ok "Frontend port 8084:80 is correct"
    log "[OK] sks-frontend-ts uses 8084:80"
    T6=$((T6 + 5))
else
    fail "Frontend port 8084:80 missing"
    log "[FAIL] sks-frontend-ts port 8084:80 missing"
fi

# Website test
TS_RESPONSE="$(curl -s --max-time 8 http://localhost:8084/wp-admin/install.php 2>/dev/null || true)"

if [[ -n "$TS_RESPONSE" ]]; then
    ok "Task 6 website responds"
    log "[OK] http://localhost:8084 responds"
else
    warn "Task 6 website does not respond"
    log "[WARN] http://localhost:8084 does not respond"
fi

(( T6 > 40 )) && T6=40

log "Task 6 Score: $T6/40"
echo "Task 6 Score: $T6/40"

# ============================================================
# FINAL SCORE
# ============================================================

# add_score() was never being called anywhere in the original script, so
# TOTAL stayed at 0 no matter what the student did. Sum the six task
# scores directly here instead.
TOTAL=$((T1 + T2 + T3 + T4 + T5 + T6))

echo ""
echo "============================================================"
echo "                  FINAL EXAM RESULT"
echo "============================================================"

if (( TOTAL >= PASS_MARK )); then
    RESULT="PASS"
else
    RESULT="FAIL"
fi

log ""
log "============================================================"
log "                  FINAL EXAM RESULT"
log "============================================================"
log "Student Name  : $STUDENT_NAME"
log "Student Email : $STUDENT_EMAIL"
log "Linux User    : $STUDENT_USER"
log ""
log "Task 1        : $T1/30"
log "Task 2        : $T2/45"
log "Task 3        : $T3/45"
log "Task 4        : $T4/65"
log "Task 5        : $T5/75"
log "Task 6        : $T6/40"
log ""
log "TOTAL         : $TOTAL/$MAX_MARK"
log "PASS MARK     : $PASS_MARK"
log "RESULT        : $RESULT"
log ""
log "Report        : $REPORT"
log "============================================================"

echo "Student Name  : $STUDENT_NAME"
echo "Student Email : $STUDENT_EMAIL"
echo ""
echo "Task 1        : $T1/30"
echo "Task 2        : $T2/45"
echo "Task 3        : $T3/45"
echo "Task 4        : $T4/65"
echo "Task 5        : $T5/75"
echo "Task 6        : $T6/40"
echo ""
echo "TOTAL         : $TOTAL/$MAX_MARK"
echo "PASS MARK     : $PASS_MARK"
echo "RESULT        : $RESULT"
echo ""
echo "Report        : $REPORT"

# ============================================================
# TELEGRAM REPORT
# ============================================================

if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] &&
   [[ -n "${TELEGRAM_CHAT_ID:-}" ]]; then

    TELEGRAM_MESSAGE="ACME Podman Exam

Student Name: $STUDENT_NAME
Student Email: $STUDENT_EMAIL
Linux User: $STUDENT_USER

Task 1: $T1/30
Task 2: $T2/45
Task 3: $T3/45
Task 4: $T4/65
Task 5: $T5/75
Task 6: $T6/40

TOTAL: $TOTAL/$MAX_MARK
PASS MARK: $PASS_MARK
RESULT: $RESULT

Report: $REPORT"

    if curl \
        -fsS \
        --max-time 10 \
        -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=$TELEGRAM_MESSAGE" \
        >/dev/null 2>&1
    then
        ok "Telegram notification sent"
    else
        warn "Telegram notification failed"
        log "[WARN] Telegram notification failed"
    fi

else
    warn "Telegram credentials are not configured"
    log "[WARN] Telegram credentials are not configured"
fi

echo ""
echo "============================================================"

exit 0