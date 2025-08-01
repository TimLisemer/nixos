# restic_backups.nix
{
  config,
  pkgs,
  lib,
  backupPaths,
  hostName,
  ...
}: let
  getLocation = path: let
    cleanParts = lib.filter (x: x != "") (lib.splitString "/" path);
  in
    if (lib.hasPrefix "/home/" path) && (builtins.length cleanParts >= 2) && (builtins.elemAt cleanParts 0 == "home")
    then let
      username = builtins.elemAt cleanParts 1;
      subParts = lib.drop 2 cleanParts;
      subPathStr =
        if subParts == []
        then ""
        else "/" + lib.concatStringsSep "_" subParts;
    in
      "user_home/" + username + subPathStr
    else if (lib.hasPrefix "/mnt/docker-data/volumes/" path) && (builtins.length cleanParts >= 4) && (builtins.elemAt cleanParts 0 == "mnt") && (builtins.elemAt cleanParts 1 == "docker-data") && (builtins.elemAt cleanParts 2 == "volumes")
    then "docker_volume/" + (lib.concatStringsSep "_" (lib.drop 3 cleanParts))
    else "system";
in {
  # ─── Restic Backup Configuration ────────────────────────────────────────────────
  sops.templates = lib.listToAttrs (builtins.map (path: let
      location = getLocation path;
      name = "backup-${hostName}-${lib.replaceStrings ["/"] ["-"] (lib.removePrefix "/" path)}";
    in {
      name = "restic_repo_${name}";
      value = {
        owner = "root";
        mode = "0400";
        content = "${config.sops.placeholder."restic_repo_base"}/${hostName}/${location}";
        restartUnits = ["restic-backups-${name}.service"];
      };
    })
    backupPaths);
  services.restic.backups = lib.listToAttrs (builtins.map (path: let
      location = getLocation path;
      name = "backup-${hostName}-${lib.replaceStrings ["/"] ["-"] (lib.removePrefix "/" path)}";
    in {
      name = name;
      value = {
        initialize = true;
        paths = [path];
        passwordFile = config.sops.secrets.restic_password.path;
        environmentFile = config.sops.secrets.restic_environment.path;
        repositoryFile = config.sops.templates."restic_repo_${name}".path;
        pruneOpts = ["--keep-daily 7" "--keep-weekly 4" "--keep-monthly 12"];
        timerConfig.OnCalendar = "06:30";
        timerConfig.Persistent = false;
      };
    })
    backupPaths);
  # Generate JSON for backup paths
  environment.etc."restic_backup_paths.json".text = builtins.toJSON (builtins.map (path: {
      native_path = path;
      repo_subpath = getLocation path;
    })
    backupPaths);

  # Restic helper scripts
  environment.systemPackages = with pkgs;
    lib.mkAfter [
      # Show how much space a given PATH occupies in the repository
      (pkgs.writeShellScriptBin "restic_size" ''
        #! /usr/bin/env bash
        set -euo pipefail

        # Color definitions
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        BLUE='\033[0;34m'
        BOLD='\033[1m'
        NC='\033[0m' # No Color

        echo_info() { echo -e "''${BLUE}''${BOLD}[INFO]''${NC} $1"; }
        echo_success() { echo -e "''${GREEN}''${BOLD}[SUCCESS]''${NC} $1"; }
        echo_error() { echo -e "''${RED}''${BOLD}[ERROR]''${NC} $1" >&2; }

        ENV_FILE="/run/secrets/restic_environment"
        REPO_BASE_FILE="/run/secrets/restic_repo_base"
        REPO_BASE="$(sudo cat "$REPO_BASE_FILE")"
        HOST="$(hostname -s)"
        PWD_FILE="/run/secrets/restic_password"
        PATHS_FILE="/etc/restic_backup_paths.json"

        if [[ $# -ne 1 ]]; then
          echo_error "Usage: restic_size <native_path>"
          exit 1
        fi
        NATIVE_PATH="$(sudo realpath "$1")"
        echo_info "Checking size for path: ''${BOLD}$NATIVE_PATH''${NC}"

        # Find the repo subpath for the native path
        SUBPATH=$(sudo jq -r --arg p "$NATIVE_PATH" '.[] | select(.native_path == $p) | .repo_subpath' "$PATHS_FILE")
        if [[ -z "$SUBPATH" ]]; then
          echo_error "No backup repository found for path '$NATIVE_PATH'."
          exit 1
        fi

        REPO="$REPO_BASE/$HOST/$SUBPATH"

        echo_info "Verifying if path exists in snapshots..."
        if ! sudo env $(sudo grep -v '^#' "$ENV_FILE" | xargs) \
             restic --repo "$REPO" --password-file "$PWD_FILE" \
             snapshots --json --path "$NATIVE_PATH" >/dev/null 2>&1; then
          echo_error "Path '$NATIVE_PATH' is not present in any snapshot in repo '$REPO'."
          exit 1
        fi
        echo_success "Path found in snapshots."

        echo_info "Calculating size..."
        BYTES=$(sudo env $(sudo grep -v '^#' "$ENV_FILE" | xargs) \
                 restic --repo "$REPO" --password-file "$PWD_FILE" \
                 stats latest --mode raw-data --json --path "$NATIVE_PATH" 2>/dev/null \
                 | jq '.total_size' 2>/dev/null || echo "0")
        echo_success "$NATIVE_PATH: ''${BOLD}$(numfmt --to=iec --suffix=B "$BYTES")''${NC}"
      '')

      # List every unique path stored in the repo together with its size
      (pkgs.writeShellScriptBin "restic_list" ''
        #! /usr/bin/env bash
        set -euo pipefail

        # Color definitions
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        BLUE='\033[0;34m'
        BOLD='\033[1m'
        NC='\033[0m' # No Color

        echo_info() { echo -e "''${BLUE}''${BOLD}[INFO]''${NC} $1"; }
        echo_success() { echo -e "''${GREEN}''${BOLD}[SUCCESS]''${NC} $1"; }
        echo_error() { echo -e "''${RED}''${BOLD}[ERROR]''${NC} $1" >&2; }

        ENV_FILE="/run/secrets/restic_environment"
        REPO_BASE_FILE="/run/secrets/restic_repo_base"
        REPO_BASE="$(sudo cat "$REPO_BASE_FILE")"
        HOST="$(hostname -s)"
        PWD_FILE="/run/secrets/restic_password"
        PATHS_FILE="/etc/restic_backup_paths.json"

        echo_info "Listing all backups for host ''${BOLD}$HOST''${NC}..."

        # Group by category
        declare -A categories
        categories["user_home"]="User Home Backups"
        categories["docker_volume"]="Docker Volume Backups"
        categories["system"]="System Backups"

        grand_total=0
        for cat_prefix in "user_home" "docker_volume" "system"; do
          cat_name="''${categories[$cat_prefix]}"
          echo -e "''${BOLD}$cat_name''${NC}"
          entries=$(sudo jq -r --arg prefix "$cat_prefix" '.[] | select(.repo_subpath | startswith($prefix)) | .native_path + "|" + .repo_subpath' "$PATHS_FILE" | sort)
          if [[ -z "$entries" ]]; then
            echo "No backups in this category."
            echo
            continue
          fi
          printf "%-60s %-100s %-10s\n" "Native Path" "Backup Repo" "Size"
          printf "%-60s %-100s %-10s\n" "------------" "------------" "----"
          total_bytes=0
          while IFS='|' read -r native_path subpath; do
            REPO="$REPO_BASE/$HOST/$subpath"
            BYTES=$(sudo env $(sudo grep -v '^#' "$ENV_FILE" | xargs) \
                     restic --repo "$REPO" --password-file "$PWD_FILE" \
                     stats latest --mode raw-data --json --path "$native_path" 2>/dev/null \
                     | jq '.total_size' 2>/dev/null || echo "0")
            SIZE=$(numfmt --to=iec --suffix=B "$BYTES")
            printf "%-60s %-100s %-10s\n" "$native_path" "$REPO" "$SIZE"
            total_bytes=$((total_bytes + BYTES))
          done <<< "$entries"
          category_total=$(numfmt --to=iec --suffix=B "$total_bytes")
          printf "\n%-60s %-100s %-10s\n" "Total for $cat_name:" "" "$category_total"
          echo
          grand_total=$((grand_total + total_bytes))
        done

        grand_total_size=$(numfmt --to=iec --suffix=B "$grand_total")
        echo -e "''${BOLD}Grand Total Disk Space in Use: ''${NC} $grand_total_size"

        echo_success "Listing complete."
      '')

      # Restore the latest snapshot of PATH into /tmp/restic/partial…
      (pkgs.writeShellScriptBin "restic_restore_to_tmp" ''
        #! /usr/bin/env bash
        set -euo pipefail

        # Color definitions
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        BLUE='\033[0;34m'
        BOLD='\033[1m'
        NC='\033[0m' # No Color

        echo_info() { echo -e "''${BLUE}''${BOLD}[INFO]''${NC} $1"; }
        echo_success() { echo -e "''${GREEN}''${BOLD}[SUCCESS]''${NC} $1"; }
        echo_error() { echo -e "''${RED}''${BOLD}[ERROR]''${NC} $1" >&2; }

        ENV_FILE="/run/secrets/restic_environment"
        REPO_BASE_FILE="/run/secrets/restic_repo_base"
        REPO_BASE="$(sudo cat "$REPO_BASE_FILE")"
        HOST="$(hostname -s)"
        PWD_FILE="/run/secrets/restic_password"
        PATHS_FILE="/etc/restic_backup_paths.json"

        if [[ $# -eq 0 ]]; then
          echo_info "No path argument provided, restoring all paths for ''${BOLD}$HOST''${NC}. Use ''${BOLD}restic_list''${NC} for a full overview of all paths."
          DEST="/tmp/restic/complete"
          echo_info "Preparing destination: ''${BOLD}$DEST''${NC}"
          sudo rm -rf "$DEST"
          sudo mkdir -p "$DEST"

          echo_info "Starting full restore..."
          entries=$(sudo jq -r '.[] | .native_path + "|" + .repo_subpath' "$PATHS_FILE")
          while IFS='|' read -r native_path subpath; do
            REPO="$REPO_BASE/$HOST/$subpath"
            echo_info "Restoring ''${BOLD}$native_path''${NC} from ''${BOLD}$REPO''${NC}..."
            sudo env $(sudo grep -v '^#' "$ENV_FILE" | xargs) \
              restic --repo "$REPO" --password-file "$PWD_FILE" \
              restore latest --path "$native_path" --target "$DEST"
          done <<< "$entries"

          echo_success "Full restore finished at ''${BOLD}$DEST''${NC}"
          exit 0
        elif [[ $# -ne 1 ]]; then
          echo_error "Usage: restic_restore_to_tmp <path>"
          exit 1
        fi

        SRC="$(sudo realpath "$1")"
        echo_info "Restoring path: ''${BOLD}$SRC''${NC}"

        # Find the repo subpath for the native path
        SUBPATH=$(sudo jq -r --arg p "$SRC" '.[] | select(.native_path == $p) | .repo_subpath' "$PATHS_FILE")
        if [[ -z "$SUBPATH" ]]; then
          echo_error "No backup repository found for path '$SRC'."
          exit 1
        fi

        REPO="$REPO_BASE/$HOST/$SUBPATH"

        echo_info "Verifying if path exists in snapshots..."
        if ! sudo env $(sudo grep -v '^#' "$ENV_FILE" | xargs) \
             restic --repo "$REPO" --password-file "$PWD_FILE" \
             snapshots --json --path "$SRC" >/dev/null 2>&1; then
          echo_error "Path '$SRC' is not present in any snapshot in repo '$REPO'."
          exit 1
        fi
        echo_success "Path found in snapshots."

        DEST="/tmp/restic/partial"
        echo_info "Preparing destination: ''${BOLD}$DEST''${NC}"
        sudo rm -rf "$DEST"
        sudo mkdir -p "$DEST"

        echo_info "Starting restore..."
        sudo env $(sudo grep -v '^#' "$ENV_FILE" | xargs) \
          restic --repo "$REPO" --password-file "$PWD_FILE" \
          restore latest --path "$SRC" --target "$DEST"

        echo_success "Restore finished at ''${BOLD}$DEST''${NC}"
      '')

      # --- restic_start_backup -------------------------------------------------
      (pkgs.writeShellScriptBin "restic_start_backup" ''
        #! /usr/bin/env bash
        set -euo pipefail

        # Color definitions
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        BLUE='\033[0;34m'
        BOLD='\033[1m'
        NC='\033[0m' # No Color

        echo_info() { echo -e "''${BLUE}''${BOLD}[INFO]''${NC} $1"; }
        echo_success() { echo -e "''${GREEN}''${BOLD}[SUCCESS]''${NC} $1"; }
        echo_error() { echo -e "''${RED}''${BOLD}[ERROR]''${NC} $1" >&2; }

        host="$(hostname -s)"
        echo_info "Starting all backup units for host: ''${BOLD}$host''${NC}"

        units=$(sudo systemctl list-unit-files --type=service --plain | grep "^restic-backups-backup-$host-" | awk '{print $1}')
        if [[ -z "$units" ]]; then
          echo_error "No backup units found."
          exit 1
        fi

        for unit in $units; do
          echo_info "Starting ''${BOLD}$unit''${NC}"
          if sudo systemctl start "$unit"; then
            echo_success "$unit started successfully."
          else
            echo_error "Failed to start $unit."
          fi
        done

        echo_info "You can follow the logs with: ''${BOLD}restic_logs''${NC}"
      '')

      # --- restic_logs ---------------------------------------------------------
      (pkgs.writeShellScriptBin "restic_logs" ''
        #! /usr/bin/env bash
        set -euo pipefail

        # Color definitions
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        BLUE='\033[0;34m'
        BOLD='\033[1m'
        NC='\033[0m' # No Color

        echo_info() { echo -e "''${BLUE}''${BOLD}[INFO]''${NC} $1"; }
        echo_success() { echo -e "''${GREEN}''${BOLD}[SUCCESS]''${NC} $1"; }
        echo_error() { echo -e "''${RED}''${BOLD}[ERROR]''${NC} $1" >&2; }

        host="$(hostname -s)"
        echo_info "Following logs for all restic backup units on ''${BOLD}$host''${NC}"
        echo_info "Showing last 100 lines and following..."

        sudo journalctl -u "restic-backups-backup-$host-*" -n 100 --follow
      '')
    ];
}
