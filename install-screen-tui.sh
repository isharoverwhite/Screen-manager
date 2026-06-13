#!/usr/bin/env bash
# =============================================================================
# install-screen-tui.sh — Self-Contained Installer for screen-tui
# Version: 3.0.0
# Description: Single-file installer with the full screen-tui script embedded
#              in PLAIN TEXT at the end of this file. No encoding, no base64.
#              Open this file in any editor to inspect the embedded script.
#              Works on Debian/Ubuntu, Arch, Fedora, and macOS.
#
# TRANSPARENCY: This file contains two scripts concatenated:
#   Lines 1 ~ N      → installer logic (this code)
#   After __EMBED__  → screen-tui script (pure Bash, ~1400+ lines)
#
# INSPECT THE EMBEDDED SCRIPT:
#   ./install-screen-tui.sh --extract | less       # View original source
#   sed '0,/^__EMBED__$/d' install-screen-tui.sh   # Extract with standard tools
#   ./install-screen-tui.sh --extract | sha256sum  # Verify checksum
#
# HOW IT WORKS:
#   - Bash executes lines 1 to 'exit 0' (the installer)
#   - Everything after '__EMBED__' is the screen-tui script, never executed
#   - install_script() uses sed to extract content after the marker
#   - Version is auto-detected from the embedded script at runtime
#
# =============================================================================
#
# Usage:
#   ./install-screen-tui.sh                 Full install (script + hooks + PATH)
#   ./install-screen-tui.sh --update        Update screen-tui from embedded copy
#   ./install-screen-tui.sh --uninstall     Remove screen-tui and all hooks
#   ./install-screen-tui.sh --extract       Print embedded screen-tui source
#   ./install-screen-tui.sh --help          Show help
#   ./install-screen-tui.sh --version       Show version
#
# One-line install:
#   curl -sL https://raw.githubusercontent.com/ryzen30xx/Screen-manager/main/install-screen-tui.sh | bash
# =============================================================================

set -euo pipefail

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 1: Constants & Configuration
# ═════════════════════════════════════════════════════════════════════════════

INSTALLER_VERSION="3.0.0"
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="screen-tui"
INSTALL_PATH="$INSTALL_DIR/$SCRIPT_NAME"
EMBED_MARKER="__EMBED__"

# ── Marker strings for idempotent hook management ──────────────────────────
# These markers delimit installer-managed blocks in shell config files.
# The installer only touches content between these markers.
HOOK_MARKER="# >>> screen-tui auto-launch (install-screen-tui) >>>"
HOOK_ENDMARKER="# <<< screen-tui auto-launch (install-screen-tui) <<<"
PATH_MARKER="# >>> screen-tui PATH (install-screen-tui) >>>"
PATH_ENDMARKER="# <<< screen-tui PATH (install-screen-tui) <<<"

# ── Shell config files to manage (in order of priority) ────────────────────
SHELL_CONFIGS=(
    "$HOME/.zshrc"
    "$HOME/.bashrc"
    "$HOME/.zprofile"
    "$HOME/.profile"
)

# ── Terminal colors ────────────────────────────────────────────────────────
BOLD='\x1b[1m'
GREEN='\x1b[1;32m'
YELLOW='\x1b[1;33m'
RED='\x1b[1;31m'
CYAN='\x1b[1;36m'
BLUE='\x1b[1;34m'
RESET='\x1b[0m'

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 2: Utility Functions
# ═════════════════════════════════════════════════════════════════════════════

# ── print_header() — Display installer banner ──────────────────────────────
print_header() {
    local ver; ver=$(detect_embedded_version)
    printf "${CYAN}══════════════════════════════════════════════════════${RESET}\n"
    printf "${CYAN}     screen-tui v${ver} — Installer v${INSTALLER_VERSION}${RESET}\n"
    printf "${CYAN}══════════════════════════════════════════════════════${RESET}\n\n"
}

# ── Logging helpers ────────────────────────────────────────────────────────
print_step()  { printf "${BLUE}  →${RESET} %s\n" "$1"; }
print_ok()    { printf "    ${GREEN}✓${RESET} %s\n" "$1"; }
print_warn()  { printf "    ${YELLOW}⚠${RESET} %s\n" "$1"; }
print_error() { printf "    ${RED}✗${RESET} %s\n" "$1"; }

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 3: Embedded Script Extraction
# ═════════════════════════════════════════════════════════════════════════════

# ── extract_embedded() — Extract screen-tui from this installer file ───────
# Reads everything after the __EMBED__ marker line and writes to stdout.
# The content is plain text — no decoding, no base64, no tricks.
# Uses sed with range addressing: delete lines 0 through /^__EMBED__$/, print rest.
extract_embedded() {
    sed '0,/^'"${EMBED_MARKER}"'$/d' "${BASH_SOURCE[0]:-$0}"
}

# ── detect_embedded_version() — Auto-detect screen-tui version from embedded
# Parses the "# Version: X.Y.Z" line from the embedded script.
# Returns version string, or "unknown" if detection fails.
detect_embedded_version() {
    local ver
    ver=$(extract_embedded | grep -m1 '^# Version:' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "${ver:-unknown}"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 4: System Detection & Prerequisites
# ═════════════════════════════════════════════════════════════════════════════

# ── detect_package_manager() — Identify the system package manager ─────────
detect_package_manager() {
    if command -v apt &>/dev/null; then      echo "apt"
    elif command -v pacman &>/dev/null; then echo "pacman"
    elif command -v dnf &>/dev/null; then    echo "dnf"
    elif command -v brew &>/dev/null; then   echo "brew"
    else echo "unknown"; fi
}

# ── check_screen() — Verify GNU Screen is installed; offer to install ──────
# Returns 0 if screen is available (or user chooses to skip install).
# Returns 1 if installation fails.
check_screen() {
    print_step "Checking for GNU Screen..."
    if command -v screen &>/dev/null; then
        local ver
        ver=$(screen --version 2>/dev/null | head -1 || echo "unknown version")
        print_ok "GNU Screen found: $ver"
        return 0
    fi

    print_warn "GNU Screen is not installed."
    printf "    screen-tui requires GNU Screen to function.\n"
    printf "    Install GNU Screen now? [Y/n] "
    local choice; IFS= read -r choice
    if [[ "$choice" =~ ^[Nn] ]]; then
        print_warn "Skipping screen installation. screen-tui will warn when run."
        return 0
    fi

    local pm; pm=$(detect_package_manager)
    print_step "Installing GNU Screen via $pm..."
    case "$pm" in
        apt)
            sudo apt update -qq && sudo apt install -y screen || {
                print_error "Failed to install screen via apt."; return 1
            } ;;
        pacman)
            sudo pacman -S --noconfirm screen || {
                print_error "Failed to install screen via pacman."; return 1
            } ;;
        dnf)
            sudo dnf install -y screen || {
                print_error "Failed to install screen via dnf."; return 1
            } ;;
        brew)
            brew install screen || {
                print_error "Failed to install screen via brew."; return 1
            } ;;
        *)
            print_error "Cannot detect package manager. Please install GNU Screen manually:"
            printf "      Debian/Ubuntu:  sudo apt install screen\n"
            printf "      Arch Linux:     sudo pacman -S screen\n"
            printf "      Fedora:         sudo dnf install screen\n"
            printf "      macOS:          brew install screen\n"
            return 1
            ;;
    esac
    print_ok "GNU Screen installed successfully."
    return 0
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 5: Installation Core
# ═════════════════════════════════════════════════════════════════════════════

# ── create_install_dir() — Ensure ~/.local/bin exists ──────────────────────
create_install_dir() {
    print_step "Ensuring $INSTALL_DIR exists..."
    if [[ -d "$INSTALL_DIR" ]]; then
        print_ok "$INSTALL_DIR already exists."
    else
        mkdir -p "$INSTALL_DIR" || {
            print_error "Failed to create $INSTALL_DIR"
            exit 1
        }
        print_ok "Created $INSTALL_DIR"
    fi
}

# ── check_existing() — Check if screen-tui is already installed ────────────
# Prompts user whether to overwrite. Returns 0 to proceed, 1 to abort.
check_existing() {
    if [[ -f "$INSTALL_PATH" ]]; then
        local ev
        ev=$(grep -m1 '^# Version:' "$INSTALL_PATH" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        ev="${ev:-unknown}"
        local new_ver; new_ver=$(detect_embedded_version)
        print_warn "screen-tui already installed (v$ev)."
        printf "    Embedded version is v${new_ver}. Reinstall/update? [Y/n] "
        local choice; IFS= read -r choice
        if [[ "$choice" =~ ^[Nn] ]]; then
            print_ok "Keeping existing installation."
            return 1
        fi
    fi
    return 0
}

# ── install_script() — Extract and write screen-tui to ~/.local/bin/ ──────
install_script() {
    local ver; ver=$(detect_embedded_version)
    print_step "Writing screen-tui v${ver} to $INSTALL_PATH..."
    extract_embedded > "$INSTALL_PATH" || {
        print_error "Failed to extract embedded script."
        exit 1
    }
    chmod +x "$INSTALL_PATH"
    local lines; lines=$(wc -l < "$INSTALL_PATH")
    print_ok "Installed: $INSTALL_PATH ($lines lines)"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 6: PATH Setup
# ═════════════════════════════════════════════════════════════════════════════

# ── is_dir_in_path() — Check if a directory is in the current PATH ─────────
is_dir_in_path() {
    [[ ":$PATH:" == *":$1:"* ]]
}

# ── setup_path() — Add ~/.local/bin to PATH in shell config files ──────────
# Uses marker-delimited blocks for safe idempotent install/uninstall.
setup_path() {
    print_step "Setting up PATH for $INSTALL_DIR..."

    # Check runtime PATH
    if is_dir_in_path "$INSTALL_DIR"; then
        print_ok "$INSTALL_DIR is already in your runtime PATH."
    else
        print_warn "$INSTALL_DIR is not in current PATH (will take effect in new shells)."
    fi

    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    local path_block
    # Build marker-delimited PATH block
    read -r -d '' path_block << PATHBLOCK || true
${PATH_MARKER}
${path_line}
${PATH_ENDMARKER}
PATHBLOCK

    local added=false
    for cfg in "${SHELL_CONFIGS[@]}"; do
        [[ -f "$cfg" ]] || continue
        if grep -qF "$PATH_MARKER" "$cfg" 2>/dev/null; then
            print_ok "PATH marker already in $(basename "$cfg")"
        elif grep -qF '.local/bin' "$cfg" 2>/dev/null; then
            print_ok ".local/bin already referenced in $(basename "$cfg")"
        else
            printf '\n%s\n' "$path_block" >> "$cfg" || {
                print_warn "Could not write to $(basename "$cfg")"
                continue
            }
            print_ok "Added PATH to $(basename "$cfg")"
            added=true
        fi
    done

    if ! $added && ! is_dir_in_path "$INSTALL_DIR"; then
        print_warn "No shell configs found to update. Add manually:"
        printf "      %s\n" "$path_line"
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 7: Auto-Launch Hooks
# ═════════════════════════════════════════════════════════════════════════════

# ── add_hooks() — Add auto-launch hooks to ALL shell config files ──────────
# Installs marker-delimited blocks containing:
#   1. Auto-launch screen-tui when NOT in a screen session (TTY, interactive)
#   2. Screen session indicator when INSIDE a screen session
# Hooks are idempotent — safe to run multiple times.
add_hooks() {
    print_step "Adding auto-launch hooks to shell configs..."

    local hook_block
    read -r -d '' hook_block << 'HOOKBLOCK' || true
${HOOK_MARKER}
# ── screen-tui Auto-Launch & Session Indicator ──────────────────────────
# Managed by install-screen-tui.sh — do not edit manually.
# To remove: run install-screen-tui.sh --uninstall

# 1) Auto-launch screen-tui when NOT inside a screen session
#    Conditions: no STY (not in screen), TTY present, interactive shell,
#    terminal is not "dumb", script exists and is executable.
if [[ -z "$STY" ]] && [[ -t 0 ]] && [[ "$TERM" != "dumb" ]] && [[ $- =~ i ]] && [[ -x ~/.local/bin/screen-tui ]]; then
    if command -v screen &>/dev/null; then
        ~/.local/bin/screen-tui
    elif [[ ! -f ~/.screen_tui_warned ]]; then
        echo "Warning: GNU Screen is not installed. Install it for screen-tui support." >&2
        touch ~/.screen_tui_warned
    fi
fi

# 2) Screen session indicator — show current session name when inside screen
#    Sets terminal title and prints a subtle indicator line.
if [[ -n "$STY" ]] && [[ -t 0 ]] && [[ "$TERM" != "dumb" ]] && [[ $- =~ i ]]; then
    SCREEN_NAME="${STY#*.}"
    printf '\033[1;32mScreen: %s \342\224\200\342\224\200\342\226\270\033[0m\n' "$SCREEN_NAME"
    printf '\033]0;Screen: %s\007' "$SCREEN_NAME"
fi
${HOOK_ENDMARKER}
HOOKBLOCK

    local added_any=false
    for cfg in "${SHELL_CONFIGS[@]}"; do
        [[ -f "$cfg" ]] || continue
        if grep -qF "$HOOK_MARKER" "$cfg" 2>/dev/null; then
            print_ok "Hook already in $(basename "$cfg")"
        else
            printf '\n%s\n' "$hook_block" >> "$cfg" || {
                print_warn "Could not write to $(basename "$cfg")"
                continue
            }
            print_ok "Added hook to $(basename "$cfg")"
            added_any=true
        fi
    done

    if ! $added_any; then
        print_warn "No new hooks added (already present or no shell configs found)."
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 8: Self-Installation (installer persistence)
# ═════════════════════════════════════════════════════════════════════════════

# ── self_install() — Copy installer to ~/.local/bin/ for future --update ───
# Allows users to run `install-screen-tui --update` without re-downloading.
self_install() {
    local src; src="${BASH_SOURCE[0]:-$0}"
    local dst="$INSTALL_DIR/install-screen-tui"

    # Resolve source to absolute path if possible
    if [[ "$src" != /* ]]; then
        src="$(pwd)/$src"
    fi

    # Only copy if source is different from destination
    if [[ "$src" != "$dst" ]] && [[ -f "$src" ]]; then
        if cp "$src" "$dst" 2>/dev/null; then
            chmod +x "$dst"
            print_ok "Installer saved to $dst"
        else
            print_warn "Could not copy installer to $dst (--update from download will still work)"
        fi
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 9: Success Display
# ═════════════════════════════════════════════════════════════════════════════

# ── print_success() — Display post-install summary ─────────────────────────
print_success() {
    local ver; ver=$(detect_embedded_version)
    printf '\n'
    printf "${GREEN}══════════════════════════════════════════════════════${RESET}\n"
    printf "${GREEN}  ✓ screen-tui v${ver} installed successfully!${RESET}\n"
    printf "${GREEN}══════════════════════════════════════════════════════${RESET}\n\n"
    printf "  ${BOLD}Quick start:${RESET}\n"
    printf '    source ~/.zshrc    # (or ~/.bashrc / ~/.profile)\n'
    printf '    screen-tui --help\n\n'
    printf "  ${BOLD}Commands:${RESET}\n"
    printf '    screen-tui                     Launch the TUI\n'
    printf '    install-screen-tui --extract   View embedded source\n'
    printf '    install-screen-tui --update    Update screen-tui\n'
    printf '    install-screen-tui --uninstall Remove everything\n\n'
    printf "  ${BOLD}Installed to:${RESET} $INSTALL_PATH\n"
    printf "  ${BOLD}Hooks added to:${RESET} ~/.zshrc ~/.bashrc ~/.zprofile ~/.profile\n"
    printf "  ${BOLD}Quit key:${RESET} Ctrl+X (inside screen-tui)\n\n"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 10: Full Install
# ═════════════════════════════════════════════════════════════════════════════

# ── do_install() — Perform complete installation ────────────────────────────
do_install() {
    print_header
    check_screen || {
        print_error "Screen installation check failed. Aborting."
        exit 1
    }
    check_existing || return 0
    create_install_dir
    install_script
    setup_path
    add_hooks
    self_install
    print_success
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 11: Update (script only)
# ═════════════════════════════════════════════════════════════════════════════

# ── do_update() — Update screen-tui script, leave hooks and PATH untouched ──
do_update() {
    print_header
    printf "${YELLOW}  Update mode: script only (hooks and PATH unchanged)${RESET}\n\n"

    if [[ ! -f "$INSTALL_PATH" ]]; then
        print_warn "screen-tui is not installed. Use full install instead:"
        printf "    Run: install-screen-tui.sh (without --update)\n"
        exit 1
    fi

    local old_ver
    old_ver=$(grep -m1 '^# Version:' "$INSTALL_PATH" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    old_ver="${old_ver:-unknown}"
    local new_ver; new_ver=$(detect_embedded_version)

    print_step "Current: v$old_ver  →  New: v${new_ver}"

    if [[ "$old_ver" == "$new_ver" ]]; then
        print_ok "Already at latest version (v${new_ver})."
        exit 0
    fi

    # Write updated script
    extract_embedded > "$INSTALL_PATH" || {
        print_error "Failed to extract embedded script."
        exit 1
    }
    chmod +x "$INSTALL_PATH"
    print_ok "Updated: $INSTALL_PATH"

    printf '\n'
    printf "${GREEN}  ✓ screen-tui updated: ${old_ver} → ${new_ver}${RESET}\n\n"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 12: Uninstall
# ═════════════════════════════════════════════════════════════════════════════

# ── remove_hooks() — Remove marker-delimited blocks and legacy artifacts ───
# Cleans up both current marker-based blocks and legacy old-format blocks.
remove_hooks() {
    print_step "Removing hooks and PATH additions from shell configs..."

    for cfg in "${SHELL_CONFIGS[@]}"; do
        [[ -f "$cfg" ]] || continue

        local tmpfile; tmpfile=$(mktemp) || {
            print_warn "Could not create temp file for $(basename "$cfg")"
            continue
        }

        # Remove marker-delimited blocks (both HOOK and PATH markers)
        sed -e "/^# >>> screen-tui auto-launch/,/^# <<< screen-tui auto-launch/d" \
            -e "/^# >>> screen-tui PATH/,/^# <<< screen-tui PATH/d" \
            "$cfg" > "$tmpfile"

        # Legacy cleanup: old format without proper markers (Phase-based comments)
        if grep -qF "screen-tui auto-launch (Phase" "$tmpfile" 2>/dev/null; then
            awk '
                /^#.*screen-tui auto-launch/ { in_block=1; next }
                in_block && /^fi$/              { in_block=0; next }
                !in_block { print }
            ' "$tmpfile" > "${tmpfile}.2"
            mv "${tmpfile}.2" "$tmpfile"
        fi

        # Legacy: remove old "Added by install-screen-tui" PATH lines
        if grep -qF "Added by install-screen-tui" "$tmpfile" 2>/dev/null; then
            grep -vF "Added by install-screen-tui" "$tmpfile" | \
                grep -vF 'export PATH="$HOME/.local/bin:$PATH"' > "${tmpfile}.2" || true
            mv "${tmpfile}.2" "$tmpfile"
        fi

        # Only overwrite if changes were made
        if ! diff -q "$cfg" "$tmpfile" &>/dev/null; then
            cp "$tmpfile" "$cfg" || {
                print_warn "Could not update $(basename "$cfg")"
                rm -f "$tmpfile"
                continue
            }
            print_ok "Cleaned hooks from $(basename "$cfg")"
        fi

        rm -f "$tmpfile"
    done

    # Remove warning suppression file
    rm -f "$HOME/.screen_tui_warned"
}

# ── do_uninstall() — Remove screen-tui, hooks, and installer copy ──────────
do_uninstall() {
    print_header
    printf "${YELLOW}  This will remove screen-tui and all related shell hooks.${RESET}\n"
    printf "  The following will be removed:\n"
    printf "    - %s\n" "$INSTALL_PATH"
    printf "    - %s\n" "$INSTALL_DIR/install-screen-tui"
    printf "    - All screen-tui hooks from shell configs\n"
    printf "    - ~/.screen_tui_warned\n"
    printf "\n"
    printf "  Continue? [y/N] "
    local choice; IFS= read -r choice
    if [[ ! "$choice" =~ ^[Yy] ]]; then
        print_ok "Uninstall cancelled."
        exit 0
    fi

    printf '\n'

    # Remove binary
    if [[ -f "$INSTALL_PATH" ]]; then
        rm -f "$INSTALL_PATH"
        print_ok "Removed $INSTALL_PATH"
    else
        print_ok "screen-tui binary not found (already removed)"
    fi

    # Remove installer copy
    if [[ -f "$INSTALL_DIR/install-screen-tui" ]]; then
        rm -f "$INSTALL_DIR/install-screen-tui"
        print_ok "Removed $INSTALL_DIR/install-screen-tui"
    fi

    # Remove hooks
    remove_hooks

    printf '\n'
    printf "${GREEN}  ✓ screen-tui uninstalled completely.${RESET}\n"
    printf '    ~/.local/bin directory was NOT removed.\n'
    printf '    GNU Screen was NOT removed.\n\n'
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 13: Help & Version
# ═════════════════════════════════════════════════════════════════════════════

# ── show_help() — Print usage information ──────────────────────────────────
show_help() {
    local ver; ver=$(detect_embedded_version)
    cat << HELPEOF
install-screen-tui.sh — Installer version ${INSTALLER_VERSION}
Embedded screen-tui version: ${ver}

Usage: install-screen-tui.sh [OPTIONS]

A self-contained installer for screen-tui — GNU Screen Terminal UI Manager.
The full screen-tui script is embedded in PLAIN TEXT at the end of this file.
Use --extract to inspect the original source code before installing.
No encoding, no base64 — open this file in any editor to see the code.

Options:
  --help, -h      Show this help message and exit
  --version, -V   Show version information and exit
  --extract       Print the embedded screen-tui source to stdout
  --uninstall     Remove screen-tui and all shell hooks
  --update, -u    Update screen-tui script only (skip hooks and PATH)

What this installer does:
  1. Checks for GNU Screen (offers to install if missing)
  2. Creates ~/.local/bin/ if needed
  3. Extracts screen-tui from this file and writes to ~/.local/bin/
  4. Adds ~/.local/bin to PATH in shell config files
  5. Adds auto-launch hooks to ~/.zshrc, ~/.bashrc, ~/.zprofile, ~/.profile
  6. Copies itself to ~/.local/bin/install-screen-tui for future updates

Shell configs managed:
  ~/.zshrc ~/.bashrc ~/.zprofile ~/.profile

Supported platforms:
  Debian/Ubuntu, Arch Linux, Fedora, macOS (Homebrew)

One-line install:
  curl -sL https://raw.githubusercontent.com/ryzen30xx/Screen-manager/main/install-screen-tui.sh | bash

After installation:
  screen-tui auto-launches on every new terminal session.
  Press Ctrl+X inside screen-tui to quit to normal terminal.
HELPEOF
    exit 0
}

# ── show_version() — Print version information ─────────────────────────────
show_version() {
    local ver; ver=$(detect_embedded_version)
    echo "install-screen-tui.sh version ${INSTALLER_VERSION}"
    echo "Embedded screen-tui version: ${ver}"
    exit 0
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 14: Main Entry Point
# ═════════════════════════════════════════════════════════════════════════════

case "${1:-}" in
    --help|-h)       show_help ;;
    --version|-V)    show_version ;;
    --extract)       extract_embedded ; exit 0 ;;
    --uninstall)     do_uninstall ;;
    --update|-u)     do_update ;;
    "")              do_install ;;
    *)
        echo "install-screen-tui.sh: unknown option: $1" >&2
        echo "Try 'install-screen-tui.sh --help' for usage information." >&2
        exit 1
        ;;
esac

# ═════════════════════════════════════════════════════════════════════════════
# EMBEDDED SCRIPT — screen-tui
# ═════════════════════════════════════════════════════════════════════════════
# WHAT THIS IS:
#   Everything below the __EMBED__ marker is the COMPLETE screen-tui source
#   code. It is pure Bash, NOT encoded, NOT compiled, NOT obfuscated.
#   You can read it directly by opening this file in any text editor.
#
# HOW TO EXTRACT (standard tools, no decoding needed):
#   ./install-screen-tui.sh --extract
#   sed '0,/^__EMBED__$/d' install-screen-tui.sh
#
# HOW TO VERIFY:
#   ./install-screen-tui.sh --extract | sha256sum
#
# This section is never executed. The installer exits before reaching
# this point (see 'exit 0' in the case/esac block above).
# ═════════════════════════════════════════════════════════════════════════════
exit 0
__EMBED__
#!/usr/bin/env bash
# =============================================================================
# screen-tui — GNU Screen Terminal UI Manager (Phase 5: Session Uptime + Banner Fix)
# Version: 5.1.0
# Author:  Experience (DTK)
# Description: Pure Bash TUI for managing GNU Screen sessions.
#              Automatically displays session list on login/SSH.
#              If no sessions exist, auto-prompts to create one.
#              Phase 3: Modal kill confirmation dialog, ←→ select Yes/No,
#              force-kill attached sessions, success/failure notifications.
#              Phase 5: Session uptime counter, banner border alignment fixed,
#              credit line off-by-one corrected, timestamp parsing from screen -ls.
# =============================================================================

set -euo pipefail

# =============================================================================
# Global Variables
# =============================================================================
declare -a SESSIONS=()       # Array of sessions, each element: "pid|name|status|epoch"
cursor=0                     # Current cursor position in session list (index)
mode="menu"                  # Current mode: menu, confirm_kill, empty, help
SCREEN_BIN="/usr/bin/screen" # Absolute path to screen binary
SCREEN_AVAILABLE=true        # Flag: is screen installed?

# =============================================================================
# Phase 2 Variables — Performance optimization and scrolling
# =============================================================================
needs_render=true           # Flag: UI needs redraw (performance optimization)
scroll_offset=0             # Scroll position (first visible index)
prev_cursor=-1              # Previous cursor position for change detection
prev_mode=""                # Previous mode for change detection
prev_session_count=-1       # Previous session count for change detection
help_from_mode="menu"       # Mode to return to after help screen
confirm_choice=1            # 0=Yes, 1=No — selection in confirmation modal (default No for safety)
kill_target_idx=-1          # Index in SESSIONS of session to kill (used by confirm modal)
show_goodbye=false          # Flag: flash "Goodbye!" on clean exit (q key), not on Ctrl+C

# =============================================================================
# Color & Style Helpers — Kali Linux / Hacker Aesthetic
# Usage: printf '%sTEXT%s\n' "$(green)" "$(reset)"
# These emit raw ANSI escape sequences for terminal styling.
# =============================================================================
green()   { printf '\x1b[1;32m'; }    # ▸ Bright green — primary Kali accent
red()     { printf '\x1b[1;31m'; }    # ▸ Bright red — danger, kill, warnings
yellow()  { printf '\x1b[1;33m'; }    # ▸ Bright yellow — attached, cautions
cyan()    { printf '\x1b[1;36m'; }    # ▸ Bright cyan — info, headers
white()   { printf '\x1b[1;37m'; }    # ▸ Bold white
bold()    { printf '\x1b[1m'; }       # ▸ Bold
dim()     { printf '\x1b[2m'; }       # ▸ Dim / faint
reset()   { printf '\x1b[0m'; }       # ▸ Reset all attributes
success() { printf '\x1b[1;32m'; }    # ▸ Alias: bright green
error()   { printf '\x1b[1;31m'; }    # ▸ Alias: bright red
warn()    { printf '\x1b[1;33m'; }    # ▸ Alias: bright yellow

# Generic color-code helper: color "1;32" = bold green, color "0" = reset
color()  { printf '\x1b[%sm' "$1"; }

# Reverse-video helper (used for row highlighting)
reverse() { printf '\x1b[7m'; }

# Background helpers
bg_red()   { printf '\x1b[41m'; }
bg_green() { printf '\x1b[42m'; }
bg_black() { printf '\x1b[40m'; }

# =============================================================================
# format_uptime() — Convert epoch seconds to short human-readable uptime string
# Examples: "30s", "5m", "2h30m", "3d12h", "--" for invalid/unknown
# =============================================================================
format_uptime() {
    local epoch="$1"
    if [[ -z "$epoch" || "$epoch" == "0" ]]; then
        printf '--'
        return
    fi
    local now elapsed days hours mins
    now=$(date +%s)
    elapsed=$((now - epoch))
    if ((elapsed < 0)); then
        printf '--'
    elif ((elapsed >= 86400)); then
        days=$((elapsed / 86400))
        hours=$(((elapsed % 86400) / 3600))
        printf '%dd%dh' "$days" "$hours"
    elif ((elapsed >= 3600)); then
        hours=$((elapsed / 3600))
        mins=$(((elapsed % 3600) / 60))
        printf '%dh%dm' "$hours" "$mins"
    elif ((elapsed >= 60)); then
        mins=$((elapsed / 60))
        printf '%dm' "$mins"
    else
        printf '%ds' "$elapsed"
    fi
}

# =============================================================================
# Check if screen is installed (early check)
# =============================================================================
if ! command -v "$SCREEN_BIN" &>/dev/null; then
    SCREEN_AVAILABLE=false
fi

# =============================================================================
# cleanup() — Terminal cleanup on exit
# Restores cursor, exits alternate buffer, and exits safely.
# Called on: SIGINT (Ctrl+C), SIGTERM, or normal exit.
# On clean exit (q key), flashes a brief "Goodbye!" message (0.5s).
# =============================================================================
cleanup() {
    # If clean exit (q key), flash goodbye message briefly
    if $show_goodbye; then
        printf '\x1b[1;36mGoodbye!\x1b[0m' 2>/dev/null || true
        sleep 0.5
    fi
    # Restore cursor visibility
    tput cnorm 2>/dev/null || printf '\x1b[?25h' 2>/dev/null || true
    # Exit alternate buffer (restore original screen)
    tput rmcup 2>/dev/null || printf '\x1b[?1049l' 2>/dev/null || true
    # Clean line break
    printf '\r\n' 2>/dev/null || true
    exit 0
}

# =============================================================================
# setup_terminal() — Configure terminal for TUI mode
# Enable alternate buffer (smcup) for full-screen drawing.
# Hide cursor (civis) for cleaner interface.
# =============================================================================
setup_terminal() {
    # Enable alternate buffer — entire TUI lives in private buffer
    tput smcup 2>/dev/null || printf '\x1b[?1049h' 2>/dev/null || true
    # Hide blinking cursor — avoid visual distraction
    tput civis 2>/dev/null || printf '\x1b[?25l' 2>/dev/null || true
}

# =============================================================================
# read_key() — Read a single key from keyboard (pure bash, no readline)
# Supports: arrow keys (↑↓←→), function keys (F5), Ctrl+L, and single keys.
# Handles escape sequences by reading byte-by-byte with timeout.
# Returns key string (empty = Enter, ESC[A = ↑, ESC[B = ↓, ESC[15~ = F5, ...)
# Extended for Phase 4: supports longer escape sequences (F5-F12).
# =============================================================================
read_key() {
    local key
    # Read first character (raw mode -r, silent -s, 1 char -n1)
    IFS= read -rsn1 key 2>/dev/null || { printf '\n'; return 1; }

    # If first char is ESC (0x1b), may be a special key (arrow, function key)
    if [[ "$key" == $'\x1b' ]]; then
        local next
        # Read next character with very short timeout (10ms)
        # If timeout → it's a plain ESC key
        if IFS= read -rsn1 -t 0.01 next 2>/dev/null; then
            key="$key$next"
            # If second char is '[' (CSI) or 'O' (SS3), read the rest of the sequence
            # This handles: arrows (ESC[A..D, ESCOA..D), F-keys (ESC[15~), etc.
            if [[ "$next" == '[' ]] || [[ "$next" == 'O' ]]; then
                # Keep reading until we get a terminating character (letter or ~)
                while IFS= read -rsn1 -t 0.01 next 2>/dev/null; do
                    key="$key$next"
                    # Terminating characters for escape sequences
                    [[ "$next" =~ [A-Za-z~] ]] && break
                done
            fi
        fi
    fi

    printf '%s' "$key"
}

# =============================================================================
# generate_screen_name() — Generate a screen session name based on current time
# Format: HHMMSS-DDMMYYYY (e.g., 143025-09052026)
# =============================================================================
generate_screen_name() {
    date +"%H%M%S-%d%m%Y"
}

# =============================================================================
# parse_screen_list() — Parse output of `screen -ls`
# Populates global SESSIONS array with "pid|name|status|epoch" entries.
# Handles cases:
#   - Screen not installed → print error, return 1
#   - "No Sockets found" → empty array, return 0
#   - Has sessions → parse each line, add to SESSIONS
# =============================================================================
parse_screen_list() {
    # Clear old array before parsing
    SESSIONS=()
    scroll_offset=0  # Reset scroll position when list changes

    # Check if screen is installed
    if ! $SCREEN_AVAILABLE; then
        echo "ERROR: GNU Screen is not installed." >&2
        echo "Please install: sudo apt install screen (Debian/Ubuntu)" >&2
        echo "            or: sudo pacman -S screen (Arch)" >&2
        echo "            or: sudo dnf install screen (Fedora)" >&2
        return 1
    fi

    # Run screen -ls and capture output (including stderr for "No Sockets")
    local screen_output
    if ! screen_output=$("$SCREEN_BIN" -ls 2>&1); then
        # screen -ls returns non-zero exit code → could be "No Sockets" or other error
        if [[ "$screen_output" =~ No\ Sockets\ found ]]; then
            # No sessions exist → return empty array (success)
            return 0
        fi
        # Unknown error
        echo "ERROR: Cannot run screen -ls: $screen_output" >&2
        return 1
    fi

    # Parse each line of screen -ls output
    # Format per session line: [tab/spaces] PID.name [spaces] (Date/Time) (Status)
    # Example: "        12345.pts-0.hostname    (01/15/2026 08:30:00 AM)    (Detached)"
    # Supports both timestamp and standard (no-timestamp) formats.
    local line pid name status epoch ts_raw ts_clean
    # New regex: captures PID, name, optional timestamp group, and status
    # BASH_REMATCH[1]=PID, [2]=name, [3]=timestamp (with parens) or empty, [4]=status
    local session_regex='^[[:space:]]+([0-9]+)\.([^[:space:]]+)[[:space:]]+(\([^)]+\)[[:space:]]+)?\(([^)]+)\)[[:space:]]*$'
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue
        # Only process lines matching PID.name + optional (timestamp) + (Status) format
        if [[ "$line" =~ $session_regex ]]; then
            pid="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
            ts_raw="${BASH_REMATCH[3]}"
            status="${BASH_REMATCH[4]}"
            # Convert timestamp to epoch if present
            epoch="0"
            if [[ -n "$ts_raw" ]]; then
                ts_clean=$(echo "$ts_raw" | sed 's/^[[:space:]]*(//; s/)[[:space:]]*$//')
                epoch=$(date -d "$ts_clean" +%s 2>/dev/null || echo "0")
            fi
            # Add to array in "pid|name|status|epoch" format
            SESSIONS+=("$pid|$name|$status|$epoch")
        fi
    done <<< "$screen_output"

    return 0
}

# =============================================================================
# attach_session() — Attach to the selected screen session (Phase 2)
# Improvements:
#   - Shows "Attaching..." message before executing
#   - If session is Attached, asks user whether to use screen -x (share)
#   - Checks session still exists before attaching (race condition guard)
# =============================================================================
attach_session() {
    local session_entry="${SESSIONS[$cursor]}"
    local pid name status

    # Split "pid|name|status|epoch" string into separate variables
    IFS='|' read -r pid name status _ <<< "$session_entry"

    # Screen session ID for attach: PID.name
    local screen_id="$pid.$name"

    # ── If session is Attached, ask user about sharing (screen -x) ──
    # screen -x allows multiple terminals to attach to the same session (multi-display)
    if [[ "$status" == "Attached" ]]; then
        # Clear bottom 3 lines (footer + 2 separators) and show prompt
        printf '\x1b[3A\x1b[J'
        printf '\x1b[1;33m'
        printf '  Session "%s" is currently in use (Attached).\n' "${name:0:30}"
        printf '\x1b[0m'
        printf '  \x1b[1m[Enter]\x1b[0m Share (screen -x)  |  \x1b[1m[Esc/q]\x1b[0m Cancel\n'
        printf '\n'

        local choice
        choice=$(read_key) || { mode="menu"; needs_render=true; return; }

        case "$choice" in
            '') # Enter — use screen -x to share session
                ;;
            $'\x1b'|q|Q) # ESC or q — cancel, return to menu
                mode="menu"
                needs_render=true
                return
                ;;
            *) # Other key — cancel, return to menu
                mode="menu"
                needs_render=true
                return
                ;;
        esac

        # Clear TUI and restore terminal
        tput rmcup 2>/dev/null || printf '\x1b[?1049l' 2>/dev/null || true
        tput cnorm 2>/dev/null || printf '\x1b[?25h' 2>/dev/null || true

        # Use screen -x to share session (multi-display mode)
        # Run screen as child process — when user detaches (Ctrl+A D),
        # screen exits and we re-launch screen-tui to show the menu.
        if "$SCREEN_BIN" -x "$screen_id"; then
            exec "$0"
        else
            printf '\n\x1b[1;31mERROR: Failed to attach to session "%s"\x1b[0m\n' "${name:0:40}" >&2
            printf 'The session may have been terminated or is inaccessible.\n' >&2
            printf 'Press Enter to exit...' >&2
            read -r _ 2>/dev/null || true
            exit 1
        fi
    fi

    # ── Show "Attaching..." message ──
    printf '\x1b[3A\x1b[J'
    printf '\x1b[1;36m'
    printf '  Attaching to session: %s ...' "${name:0:35}"
    printf '\x1b[0m\n\n'

    # ── Check session still exists before attaching ──
    # Guards against session being killed by another process between list and attach
    if ! "$SCREEN_BIN" -ls 2>/dev/null | grep -q "^[[:space:]]*${pid}\." ; then
        printf '\x1b[1;31m'
        printf '  ERROR: Session "%s" no longer exists (was killed).\n' "${name:0:30}"
        printf '\x1b[0m'
        printf '  Press any key to return to menu...\n'
        read_key > /dev/null 2>&1 || true
        parse_screen_list
        # Adjust cursor if list is shorter after re-parse
        if [[ ${#SESSIONS[@]} -gt 0 ]]; then
            [[ $cursor -ge ${#SESSIONS[@]} ]] && cursor=$((${#SESSIONS[@]} - 1))
        fi
        mode="menu"
        needs_render=true
        return
    fi

    # Clear TUI and restore terminal before attaching
    tput rmcup 2>/dev/null || printf '\x1b[?1049l' 2>/dev/null || true
    tput cnorm 2>/dev/null || printf '\x1b[?25h' 2>/dev/null || true

    # Attach to screen session as child process.
    # When user detaches (Ctrl+A D) or session ends, screen exits
    # and we re-launch screen-tui to show the menu again.
    if "$SCREEN_BIN" -r "$screen_id"; then
        exec "$0"
    else
        printf '\n\x1b[1;31mERROR: Failed to attach to session "%s"\x1b[0m\n' "${name:0:40}" >&2
        printf 'The session may have been terminated or is inaccessible.\n' >&2
        printf 'Press Enter to exit...' >&2
        read -r _ 2>/dev/null || true
        exit 1
    fi
}

# =============================================================================
# create_new_session() — Create a new screen session and attach immediately
# Prompts user to type a session name. Empty input → cancel.
# =============================================================================
create_new_session() {
    # Exit alternate buffer and restore cursor for clean input
    tput rmcup 2>/dev/null || printf '\x1b[?1049l' 2>/dev/null || true
    tput cnorm 2>/dev/null || printf '\x1b[?25h' 2>/dev/null || true

    local default_name
    default_name=$(generate_screen_name)

    printf '\x1b[1;36m══════════════════════════════════════════════════════\x1b[0m\n'
    printf '              Create New Screen Session\n'
    printf '\x1b[1;36m══════════════════════════════════════════════════════\x1b[0m\n'
    printf '\n'
    printf '  Default name: \x1b[1;32m%s\x1b[0m\n' "$default_name"
    printf '\n'
    printf '  \x1b[1mType a name + Enter\x1b[0m — Create with custom name\n'
    printf '  \x1b[1m[Enter] (empty)\x1b[0m        — Use default name above\n'
    printf '  \x1b[1m[Ctrl+C]\x1b[0m              — Cancel\n'
    printf '\n'
    printf '  Session name: \x1b[1;32m'

    # Read user input
    local custom_name
    IFS= read -r custom_name
    printf '\x1b[0m\n'

    # Use default if empty
    if [[ -z "$custom_name" ]]; then
        custom_name="$default_name"
    fi

    # Validate name (no spaces, no slashes)
    if [[ "$custom_name" =~ [[:space:]/] ]]; then
        printf '\x1b[1;31m  ERROR: Session name cannot contain spaces or slashes.\x1b[0m\n'
        printf '  Press Enter to return...'
        read -r _
        setup_terminal
        parse_screen_list
        if [[ ${#SESSIONS[@]} -eq 0 ]]; then
            mode="empty"
        else
            mode="menu"
        fi
        needs_render=true
        return
    fi

    # Show launching message
    printf '\n  \x1b[1;33mLaunching screen session: %s ...\x1b[0m\n' "$custom_name"
    sleep 0.3

    # Create new session and attach as child process.
    # When user detaches (Ctrl+A D) or session ends, screen exits
    # and we re-launch screen-tui to show the menu again.
    if "$SCREEN_BIN" -S "$custom_name"; then
        exec "$0"
    else
        printf '\n\x1b[1;31mERROR: Failed to create screen session "%s"\x1b[0m\n' "${custom_name:0:40}" >&2
        printf 'Check that GNU Screen is installed and functioning.\n' >&2
        printf 'Press Enter to exit...' >&2
        read -r _ 2>/dev/null || true
        exit 1
    fi
}

# =============================================================================
# kill_session() — Set up kill confirmation mode (Phase 3: Modal Dialog)
# Does not perform the kill directly. Only stores session index and switches mode.
# The actual kill is performed by execute_kill() after user confirms.
# =============================================================================
kill_session() {
    local session_entry="${SESSIONS[$cursor]}"
    local pid name status
    IFS='|' read -r pid name status _ <<< "$session_entry"

    # ── Store index of session to kill ──
    kill_target_idx=$cursor
    # ── Default to No (safe!) ──
    confirm_choice=1

    # ── Distinguish Attached vs Detached for appropriate modal ──
    if [[ "$status" == "Attached" ]]; then
        mode="confirm_kill_attached"
    else
        mode="confirm_kill"
    fi
    needs_render=true
}

# =============================================================================
# execute_kill() — Execute kill command after user confirms Yes (Phase 3)
# Improvements:
#   - Shows "Session [name] killed" success message for 1 second
#   - Re-checks screen -ls to confirm session was actually removed
#   - If screen -X quit fails → shows error and returns to menu
#   - If list is empty after kill → switches to empty state (auto-create prompt)
#   - Adjusts cursor: if killed session was last → move up
# =============================================================================
execute_kill() {
    local idx=$kill_target_idx
    # ── Validate index ──
    if [[ $idx -lt 0 ]] || [[ $idx -ge ${#SESSIONS[@]} ]]; then
        confirm_choice=1
        kill_target_idx=-1
        mode="menu"
        needs_render=true
        return
    fi

    local session_entry="${SESSIONS[$idx]}"
    local pid name status
    IFS='|' read -r pid name status _ <<< "$session_entry"
    local screen_id="$pid.$name"

    # ── Execute kill command ──
    local kill_success=false
    if "$SCREEN_BIN" -S "$screen_id" -X quit 2>/dev/null; then
        # Brief wait for screen to process
        sleep 0.3
        # Verify: is the session actually gone?
        if ! "$SCREEN_BIN" -ls 2>/dev/null | grep -q "^[[:space:]]*${pid}\."; then
            kill_success=true
        fi
    fi

    # ── Show result notification ──
    tput clear 2>/dev/null || printf '\x1b[2J\x1b[H' 2>/dev/null
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local box_w=48
    [[ $box_w -gt $((cols - 4)) ]] && box_w=$((cols - 4))
    local hline=''
    local i
    for ((i = 0; i < box_w - 2; i++)); do hline+='═'; done

    # ── Center the box ──
    local pad=$(( (cols - box_w) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    [[ -z "${pad:-}" ]] && pad=0

    if $kill_success; then
        # ── Success: show green notification box ──
        printf '\x1b[1;32m'
        printf '%*s╔%s╗\n' "$pad" "" "$hline"
        printf '%*s║  Session killed: %-*s ║\n' "$pad" "" "$((box_w - 20))" "${name:0:$((box_w - 20))}"
        printf '%*s╚%s╝\n' "$pad" "" "$hline"
        printf '\x1b[0m'
        sleep 1
    else
        # ── Failure: show red error box ──
        printf '\x1b[1;31m'
        printf '%*s╔%s╗\n' "$pad" "" "$hline"
        printf '%*s║  ERROR: Could not kill session              ║\n' "$pad" ""
        printf '%*s║  %-*s ║\n' "$pad" "" "$((box_w - 4))" "${name:0:$((box_w - 4))}"
        printf '%*s║  Session still exists after kill command.   ║\n' "$pad" ""
        printf '%*s╚%s╝\n' "$pad" "" "$hline"
        printf '\x1b[0m'
        printf '\n%*sPress any key to return...' "$pad" ""
        read_key > /dev/null 2>&1 || true
    fi

    # ── Re-parse session list ──
    parse_screen_list

    # ── Adjust cursor ──
    if [[ ${#SESSIONS[@]} -gt 0 ]]; then
        # If killed session was last item → move cursor up
        if [[ $idx -ge ${#SESSIONS[@]} ]]; then
            cursor=$((${#SESSIONS[@]} - 1))
        elif [[ $idx -lt ${#SESSIONS[@]} ]]; then
            # Keep cursor at approximately the same position (next session fills the gap)
            cursor=$idx
        else
            cursor=0
        fi
        mode="menu"
    else
        # List empty → switch to empty state
        mode="empty"
        cursor=0
    fi

    # ── Clean up confirm variables ──
    confirm_choice=1
    kill_target_idx=-1
    needs_render=true
}

# =============================================================================
# render_empty_ui() — Display UI when no screen sessions exist
# Simplified: banner + "no sessions" message. Prompt handled by handle_empty_state().
# =============================================================================
render_empty_ui() {
    local cols height
    cols=$(tput cols 2>/dev/null || echo 80)
    height=$(tput lines 2>/dev/null || echo 24)

    # Clear screen
    tput clear 2>/dev/null || printf '\x1b[2J\x1b[H' 2>/dev/null

    # ── Top padding (center vertically) ──
    local top_pad=$(( (height - 10) / 2 ))
    [[ $top_pad -lt 1 ]] && top_pad=1
    local row
    for ((row = 0; row < top_pad; row++)); do printf '\n'; done

    # ── Kali-style header banner ─────────────────────────────────────────
    local box_w=58
    [[ $box_w -gt $((cols - 4)) ]] && box_w=$((cols - 4))
    local pad=$(( (cols - box_w) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    [[ -z "${pad:-}" ]] && pad=0

    printf '%*s%s╔' "$pad" "" "$(green)"
    local i
    for ((i = 0; i < box_w - 2; i++)); do printf '═'; done
    printf '╗%s\n' "$(reset)"

    printf '%*s%s║%s  %s[>_]%s SCREEN-TUI v5.1 — GNU Screen Session Manager' \
        "$pad" "" "$(green)" "$(reset)" "$(green)" "$(dim)"
    local title_text="  [>_] SCREEN-TUI v5.1 — GNU Screen Session Manager"
    local fill=$((box_w - ${#title_text} - 3))
    [[ $fill -gt 0 ]] && printf '%*s' "$fill" ""
    printf ' %s║%s\n' "$(green)" "$(reset)"

    printf '%*s%s║%s  %smade by Experience (DTK)' \
        "$pad" "" "$(green)" "$(reset)" "$(dim)"
    local credit_text="  made by Experience (DTK)"
    local credit_fill=$((box_w - ${#credit_text} - 3))
    [[ $credit_fill -gt 0 ]] && printf '%*s' "$credit_fill" ""
    printf ' %s║%s\n' "$(green)" "$(reset)"

    printf '%*s%s╚' "$pad" "" "$(green)"
    for ((i = 0; i < box_w - 2; i++)); do printf '═'; done
    printf '╝%s\n\n' "$(reset)"

    # ── "No sessions" system message ─────────────────────────────────────
    printf '%*s%s  ●  %sNo active screen sessions found.%s\n\n' \
        "$pad" "" "$(yellow)" "$(white)" "$(reset)"

    # ── Status line (simulated terminal boot info) ───────────────────────
    printf '%*s%s  system ready%s  │  %s%s sessions%s  │  %s%s%s%s\n\n' \
        "$pad" "" "$(dim)" "$(reset)" "$(dim)" "$(red)" "$(dim)" "$(reset)" \
        "$(dim)" "$(date +%H:%M:%S)" "$(reset)"
}

# =============================================================================
# render_menu_ui() — Display session list as a menu (Phase 2)
# Improvements:
#   - Info bar: total sessions, selected session PID
#   - Status colors: Green (Detached), Yellow (Attached)
#   - Full-line highlight (reverse video, full-width) for selected item
#   - Shows PID in list, truncates long names with "..."
#   - Scroll indicators (▲/▼) for lists exceeding visible area
#   - Redesigned footer with horizontal divider
# =============================================================================
render_menu_ui() {
    local i entry pid name status
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)

    # ── Adjust scroll_offset so cursor is always in visible area ──
    local total=${#SESSIONS[@]}
    local visible_max=12  # Max number of session rows to display
    if [[ $total -gt $visible_max ]]; then
        if [[ $cursor -lt $scroll_offset ]]; then
            scroll_offset=$cursor
        elif [[ $cursor -ge $((scroll_offset + visible_max)) ]]; then
            scroll_offset=$((cursor - visible_max + 1))
        fi
        # Ensure scroll_offset stays within bounds
        [[ $scroll_offset -lt 0 ]] && scroll_offset=0
        if [[ $scroll_offset -gt $((total - visible_max)) ]]; then
            scroll_offset=$((total - visible_max))
        fi
        [[ $scroll_offset -lt 0 ]] && scroll_offset=0
    else
        scroll_offset=0
    fi

    # Clear screen
    tput clear 2>/dev/null || printf '\x1b[2J\x1b[H' 2>/dev/null

    # ── Kali-style Header Banner ──────────────────────────────────────────
    # Fixed-width, left-aligned banner (narrow-friendly for vertical monitors)
    local box_w=62
    [[ $box_w -gt $((cols - 2)) ]] && box_w=$((cols - 2))
    [[ $box_w -lt 40 ]] && box_w=40

    printf '%s╔' "$(green)"
    local j
    for ((j = 0; j < box_w - 2; j++)); do printf '═'; done
    printf '╗%s\n' "$(reset)"

    printf '%s║%s  %s[>_]%s SCREEN-TUI v5.1 — GNU Screen Session Manager' \
        "$(green)" "$(reset)" "$(green)" "$(dim)"
    local hdr_text="  [>_] SCREEN-TUI v5.1 — GNU Screen Session Manager"
    local hdr_fill=$((box_w - ${#hdr_text} - 3))
    [[ $hdr_fill -gt 0 ]] && printf '%*s' "$hdr_fill" ""
    printf ' %s║%s\n' "$(green)" "$(reset)"

    printf '%s║%s  %smade by Experience (DTK)' \
        "$(green)" "$(reset)" "$(dim)"
    local credit_text="  made by Experience (DTK)"
    local credit_fill=$((box_w - ${#credit_text} - 3))
    [[ $credit_fill -gt 0 ]] && printf '%*s' "$credit_fill" ""
    printf ' %s║%s\n' "$(green)" "$(reset)"

    printf '%s╚' "$(green)"
    for ((j = 0; j < box_w - 2; j++)); do printf '═'; done
    printf '╝%s\n\n' "$(reset)"

    # ── Info bar: session count, selection, PID, clock ────────────────────
    local sel_pid="" sel_name="" sel_uptime=""
    if [[ $total -gt 0 ]] && [[ $cursor -lt $total ]]; then
        IFS='|' read -r sel_pid sel_name _ sel_epoch <<< "${SESSIONS[$cursor]}"
        sel_uptime=$(format_uptime "$sel_epoch")
    fi
    local clock_str
    clock_str=$(date +%H:%M:%S)

    printf ' %s───┤%s %sSessions:%s %s%d%s  │  %sSelected:%s %s#%d%s  │  %sPID:%s %s%s%s  │  %sUptime:%s %s%s%s  │  %s%s%s %s├───%s\n' \
        "$(dim)" "$(reset)" "$(white)" "$(reset)" "$(green)" "$total" "$(reset)" \
        "$(white)" "$(reset)" "$(green)" "$((cursor + 1))" "$(reset)" \
        "$(white)" "$(reset)" "$(green)" "$sel_pid" "$(reset)" \
        "$(white)" "$(reset)" "$(green)" "$sel_uptime" "$(reset)" \
        "$(dim)" "$clock_str" "$(reset)" "$(dim)" "$(reset)"
    printf '\n'

    # ── Column headers ────────────────────────────────────────────────────
    printf '   %s%-8s  %-26s  %-18s%s\n' "$(bold)" "PID" "SESSION NAME" "STATUS / UPTIME" "$(reset)"
    local col_div=''
    printf -v col_div '%*s' "$((cols - 2))" ""
    col_div="${col_div// /─}"
    printf ' %s%s%s\n' "$(dim)" "$col_div" "$(reset)"
    printf '\n'

    # ── Scroll indicator (top) — if list is long and scrolled down ────────
    if [[ $scroll_offset -gt 0 ]]; then
        printf ' %s  ▲  %d more session(s) above  ▲%s\n' "$(dim)" "$scroll_offset" "$(reset)"
    fi

    # ── Session list (only visible range) ─────────────────────────────────
    local visible_end=$((scroll_offset + visible_max))
    [[ $visible_end -gt $total ]] && visible_end=$total

    for ((i = scroll_offset; i < visible_end; i++)); do
        entry="${SESSIONS[$i]}"
        IFS='|' read -r pid name status epoch <<< "$entry"

        # ── Compute uptime from epoch ──
        local uptime_str
        uptime_str=$(format_uptime "$epoch")

        # ── Determine status color & dot indicator ──
        local s_color s_dot s_color_dim
        if [[ "$status" == "Attached" ]]; then
            s_color='\x1b[1;33m'      # Bright yellow (selected)
            s_color_dim='\x1b[2;33m'   # Dim yellow (unselected)
            s_dot='●'
        else
            s_color='\x1b[1;32m'      # Bright green (selected)
            s_color_dim='\x1b[2;32m'   # Dim green (unselected)
            s_dot='●'
        fi

        # ── Truncate long names ──
        local disp_name="$name"
        if [[ ${#disp_name} -gt 26 ]]; then
            disp_name="${disp_name:0:23}..."
        fi

        # ── Print session row ──
        # Header: "   PID       SESSION NAME                STATUS / UPTIME  "
        # Row:    " ▶ PID       SESSION NAME                ● STATUS  UPTIME  "
        if [[ $i -eq $cursor ]]; then
            # Selected row: bright + bold + green arrow
            printf ' \x1b[1;32m▶\x1b[0m \x1b[1m%-8s  %-26s  ' "$pid" "$disp_name"
            printf "${s_color}${s_dot} %-10s\x1b[0m \x1b[2m%-7s\x1b[0m" "$status" "$uptime_str"
            printf '\n'
        else
            # Unselected row: everything dim
            printf ' \x1b[2m  %-8s  %-26s  ' "$pid" "$disp_name"
            printf "${s_color_dim}${s_dot} %-10s\x1b[0m \x1b[2m%-7s\x1b[0m" "$status" "$uptime_str"
            printf '\n'
        fi
    done

    # ── Scroll indicator (bottom) — if more sessions below visible area ───
    local remaining_below=$((total - visible_end))
    if [[ $remaining_below -gt 0 ]]; then
        printf ' %s  ▼  %d more session(s) below  ▼%s\n' "$(dim)" "$remaining_below" "$(reset)"
    fi

    printf '\n'

    # ── Footer: Keybinding status bar ─────────────────────────────────────
    local div=''
    printf -v div '%*s' "$cols" ""
    div="${div// /─}"
    printf ' %s%s%s\n' "$(dim)" "$div" "$(reset)"
    printf '  %s[↑↓]%s Nav  %s[Enter]%s Attach  %s[n]%s New  %s[x]%s Kill  %s[F5]%s Refresh  %s[h]%s Help  %s[q/Ctrl+X]%s Quit\n' \
        "$(green)" "$(reset)" "$(green)" "$(reset)" \
        "$(green)" "$(reset)" "$(red)" "$(reset)" \
        "$(green)" "$(reset)" "$(green)" "$(reset)" \
        "$(red)" "$(reset)"
}

# =============================================================================
# render_confirm_kill_modal() — Display kill confirmation modal dialog (Phase 3)
# Centered modal overlay with:
#   - Unicode box-drawing border (╔═╗ ║ ╚═╝ ╟─╢)
#   - Title "CONFIRM KILL SESSION" in bold red on blue background
#   - Session name and status displayed clearly
#   - Two buttons [▶ Yes] and [  No ] with selected button highlighted (reverse video)
#   - Instruction row: ← → to select, Enter to confirm, Esc to cancel
#   - If Attached: shows additional yellow warning row
# =============================================================================
render_confirm_kill_modal() {
    local cols height
    cols=$(tput cols 2>/dev/null || echo 80)
    height=$(tput lines 2>/dev/null || echo 24)

    # ── Get session info ──
    local session_entry="${SESSIONS[$kill_target_idx]}"
    local pid name status
    IFS='|' read -r pid name status _ <<< "$session_entry"

    # ── Display name (truncate if too long) ──
    local disp_name="$name"
    if [[ ${#disp_name} -gt 35 ]]; then
        disp_name="${disp_name:0:32}..."
    fi

    # ── Modal dimensions (slightly wider for dramatic effect) ──
    local mw=54
    [[ $mw -gt $((cols - 4)) ]] && mw=$((cols - 4))
    local mh=11

    # ── Build horizontal lines from Unicode box-drawing chars ──
    local hline=''
    local i
    for ((i = 0; i < mw - 2; i++)); do hline+='═'; done
    local hline_thin=''
    for ((i = 0; i < mw - 2; i++)); do hline_thin+='─'; done

    # ── Modal position (centered on screen) ──
    local ml=$(( (cols - mw) / 2 ))
    local mt=$(( (height - mh) / 2 ))
    [[ $ml -lt 0 ]] && ml=0
    [[ $mt -lt 0 ]] && mt=0
    [[ -z "${ml:-}" ]] && ml=0
    [[ -z "${mt:-}" ]] && mt=0

    # ── Clear screen for clean redraw ──
    tput clear 2>/dev/null || printf '\x1b[2J\x1b[H' 2>/dev/null

    # ── Draw dark background over entire screen (dim effect) ──
    printf '\x1b[40m'
    local row
    for ((row = 0; row < height; row++)); do
        printf '%*s\n' "$cols" ""
    done
    printf '\x1b[0m'

    # ── Draw modal background: black with subtle red tint ──
    for ((row = 0; row < mh; row++)); do
        printf '\x1b[%d;%dH' "$((mt + row + 1))" "$((ml + 1))"
        printf '\x1b[48;5;52m%*s\x1b[0m' "$mw" ""   # Dark maroon bg
    done

    # ── Row 1: Top border ╔═══...═══╗ + ☠ title ──
    printf '\x1b[%d;%dH' "$((mt + 1))" "$((ml + 1))"
    printf '\x1b[1;31m╔%s╗\x1b[0m' "$hline"
    printf '\x1b[%d;%dH' "$((mt + 1))" "$((ml + 2))"
    printf '\x1b[1;37;41m ☠  CONFIRM KILL SESSION  ☠ \x1b[0m'

    # ── Row 2: Divider ╟───...───╢ ──
    printf '\x1b[%d;%dH' "$((mt + 2))" "$((ml + 1))"
    printf '\x1b[1;31m╟%s╢\x1b[0m' "$hline_thin"

    # ── Row 3: Session name ──
    printf '\x1b[%d;%dH' "$((mt + 3))" "$((ml + 3))"
    printf '\x1b[1;37;48;5;52m  Session: %s\x1b[0m' "$disp_name"

    # ── Row 4: PID and status ──
    printf '\x1b[%d;%dH' "$((mt + 4))" "$((ml + 3))"
    local s_color
    if [[ "$status" == "Attached" ]]; then
        s_color='\x1b[1;33m'    # Yellow for Attached
    else
        s_color='\x1b[1;32m'    # Green for Detached
    fi
    printf '\x1b[37;48;5;52m  PID: %s   │   Status: %s%s\x1b[0m' "$pid" "$s_color" "$status"

    # ── Row 5: Warning if Attached, otherwise blank ──
    printf '\x1b[%d;%dH' "$((mt + 5))" "$((ml + 3))"
    if [[ "$mode" == "confirm_kill_attached" ]]; then
        printf '\x1b[1;33;48;5;52m  ⚠  SESSION IS IN USE (Attached) — Force-kill anyway?  ⚠\x1b[0m'
    else
        printf '\x1b[48;5;52m%*s\x1b[0m' "$((mw - 4))" ""
    fi

    # ── Row 6: Ominous warning ──
    printf '\x1b[%d;%dH' "$((mt + 6))" "$((ml + 3))"
    printf '\x1b[1;31;48;5;52m  ▐▌  This action cannot be undone!  ▐▌\x1b[0m'

    # ── Row 7: Blank spacer row ──
    printf '\x1b[%d;%dH' "$((mt + 7))" "$((ml + 3))"
    printf '\x1b[48;5;52m%*s\x1b[0m' "$((mw - 4))" ""

    # ── Row 8: Two buttons ──
    printf '\x1b[%d;%dH' "$((mt + 8))" "$((ml + 5))"
    if [[ $confirm_choice -eq 0 ]]; then
        # Yes selected → red bg + reverse video
        printf '\x1b[7;1;37;41m  [ YES, KILL IT ]  \x1b[0m'
        printf '\x1b[37;48;5;52m    [  No  ]    \x1b[0m'
    else
        # No selected
        printf '\x1b[37;48;5;52m  [ YES, KILL IT ]  \x1b[0m'
        printf '  \x1b[7;1;37;41m  [  No  ]  \x1b[0m'
    fi

    # ── Row 9: Key instructions ──
    printf '\x1b[%d;%dH' "$((mt + 9))" "$((ml + 3))"
    printf '\x1b[2;37;48;5;52m  ← → to select   │   Enter to confirm   │   Esc to cancel  \x1b[0m'

    # ── Row 10: Bottom border ╚═══...═══╝ ──
    printf '\x1b[%d;%dH' "$((mt + 10))" "$((ml + 1))"
    printf '\x1b[1;31m╚%s╝\x1b[0m' "$hline"

    # ── Row 11: Padding below modal ──
    printf '\x1b[%d;%dH' "$((mt + 11))" "$((ml + 1))"
    printf '\x1b[48;5;52m%*s\x1b[0m' "$mw" ""

    # ── Move cursor outside modal area ──
    printf '\x1b[%d;1H' "$((mt + mh + 1))"
}

# =============================================================================
# render_help_ui() — Display help screen overlay
# Shows all keyboard shortcuts and function descriptions.
# Dismisses on any key press.
# =============================================================================
render_help_ui() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)

    tput clear 2>/dev/null || printf '\x1b[2J\x1b[H' 2>/dev/null

    # ── Header banner ────────────────────────────────────────────────────
    local box_w=62
    [[ $box_w -gt $((cols - 2)) ]] && box_w=$((cols - 2))
    [[ $box_w -lt 40 ]] && box_w=40

    printf '%s╔' "$(green)"
    local j
    for ((j = 0; j < box_w - 2; j++)); do printf '═'; done
    printf '╗%s\n' "$(reset)"

    printf '%s║%s  %s[?]%s HELP — Keyboard Reference' \
        "$(green)" "$(reset)" "$(green)" "$(white)"
    local hdr_text="  [?] HELP — Keyboard Reference"
    local hdr_fill=$((box_w - ${#hdr_text} - 3))
    [[ $hdr_fill -gt 0 ]] && printf '%*s' "$hdr_fill" ""
    printf ' %s║%s\n' "$(green)" "$(reset)"

    printf '%s╚' "$(green)"
    for ((j = 0; j < box_w - 2; j++)); do printf '═'; done
    printf '╝%s\n\n' "$(reset)"

    # ── Navigation section ───────────────────────────────────────────────
    printf ' %s───┤%s %sNAVIGATION%s %s├───────────────────────────────────────────%s\n' \
        "$(dim)" "$(reset)" "$(green)" "$(reset)" "$(dim)" "$(reset)"
    printf '   %s↑ / ↓%s        Move up / down (wrap-around at edges)\n' "$(green)" "$(reset)"
    printf '   %sF5 / Ctrl+L%s  Refresh session list\n' "$(green)" "$(reset)"
    printf '   %sh%s           Show this help screen\n' "$(green)" "$(reset)"
    printf '\n'

    # ── Actions section ──────────────────────────────────────────────────
    printf ' %s───┤%s %sACTIONS%s %s├──────────────────────────────────────────────%s\n' \
        "$(dim)" "$(reset)" "$(green)" "$(reset)" "$(dim)" "$(reset)"
    printf '   %sEnter%s       Attach to selected session\n' "$(green)" "$(reset)"
    printf '                If Attached → offers shared attach (screen -x)\n'
    printf '   %sn%s           Create new screen session (prompts for name)\n' "$(green)" "$(reset)"
    printf '   %sx%s           Kill selected session (with confirmation)\n' "$(red)" "$(reset)"
    printf '   %sq / Ctrl+X%s  Quit screen-tui\n' "$(red)" "$(reset)"
    printf '   %sCtrl+C%s      Exit immediately (no goodbye)\n' "$(red)" "$(reset)"
    printf '\n'

    # ── Legend section ───────────────────────────────────────────────────
    printf ' %s───┤%s %sLEGEND%s %s├────────────────────────────────────────────────%s\n' \
        "$(dim)" "$(reset)" "$(green)" "$(reset)" "$(dim)" "$(reset)"
    printf '   %s● DETACHED%s   Session idle — ready to attach\n' "$(green)" "$(reset)"
    printf '   %s● ATTACHED%s   Session in use — can share (screen -x)\n' "$(yellow)" "$(reset)"
    printf '   %s▶%s            Selected row indicator\n' "$(green)" "$(reset)"
    printf '   %s▲ / ▼%s        More sessions above / below (scroll)\n' "$(dim)" "$(reset)"
    printf '\n'

    # ── Footer ───────────────────────────────────────────────────────────
    local div=''
    printf -v div '%*s' "$((cols - 2))" ""
    div="${div// /─}"
    printf ' %s%s%s\n' "$(dim)" "$div" "$(reset)"
    printf ' %s  Press any key to return to menu...%s\n' "$(dim)" "$(reset)"
}

# =============================================================================
# handle_help_input() — Handle key presses in help mode
# Any key returns to the previous mode (usually menu).
# =============================================================================
handle_help_input() {
    local key
    key=$(read_key) || true
    # Return to previous mode and mark for re-render
    mode="$help_from_mode"
    needs_render=true
}

# =============================================================================
# handle_confirm_input() — Handle key presses in kill confirmation modal (Phase 3)
# Supports:
#   - ← (left): select Yes button
#   - → (right): select No button
#   - ↑/↓: toggle between Yes and No
#   - Enter: confirm current selection (Yes → execute_kill, No → return to menu)
#   - ESC / q: cancel, return to menu
# =============================================================================
handle_confirm_input() {
    local key
    key=$(read_key) || { cleanup; }

    case "$key" in
        # ── Left arrow: select Yes ──
        $'\x1b[D'|$'\x1bOD')
            confirm_choice=0
            needs_render=true
            ;;
        # ── Right arrow: select No ──
        $'\x1b[C'|$'\x1bOC')
            confirm_choice=1
            needs_render=true
            ;;
        # ── Up/down arrows: also toggle Yes/No for convenience ──
        $'\x1b[A'|$'\x1bOA'|$'\x1b[B'|$'\x1bOB')
            # Up/down: toggle between Yes (0) and No (1)
            if [[ $confirm_choice -eq 0 ]]; then
                confirm_choice=1
            else
                confirm_choice=0
            fi
            needs_render=true
            ;;
        # ── Enter: confirm selection ──
        '')
            if [[ $confirm_choice -eq 0 ]]; then
                # Yes selected → execute kill
                execute_kill
            else
                # No selected → cancel, return to menu
                confirm_choice=1
                kill_target_idx=-1
                mode="menu"
                needs_render=true
            fi
            ;;
        # ── ESC or q: cancel, return to menu ──
        $'\x1b'|q|Q)
            confirm_choice=1
            kill_target_idx=-1
            mode="menu"
            needs_render=true
            ;;
        # ── Other keys: ignore, do nothing ──
        *)
            ;;
    esac
}

# =============================================================================
# render_ui() — Main render function, delegates to correct sub-renderer by mode
# Called on: initialization, state changes, and SIGWINCH (terminal resize).
# =============================================================================
render_ui() {
    case "$mode" in
        empty)
            render_empty_ui
            ;;
        confirm_kill|confirm_kill_attached)
            # Phase 3: Both confirm modes share the same modal overlay
            render_confirm_kill_modal
            ;;
        help)
            render_help_ui
            ;;
        menu|*)
            render_menu_ui
            ;;
    esac
}

# =============================================================================
# handle_empty_state() — Handle UI when no screen sessions exist
# Flow: show banner → prompt for name → validate → create → re-launch.
# Direct and simple — no intermediate menu, no keybinding loop.
# =============================================================================
handle_empty_state() {
    # ── Exit alternate buffer FIRST (was entered by setup_terminal) ──
    # We draw directly on the main screen so the banner stays visible
    # alongside the input prompt.
    tput rmcup 2>/dev/null || printf '\x1b[?1049l' 2>/dev/null || true
    tput cnorm 2>/dev/null || printf '\x1b[?25h' 2>/dev/null || true

    # ── Calculate layout ──
    local cols box_w pad
    cols=$(tput cols 2>/dev/null || echo 80)
    box_w=58
    [[ $box_w -gt $((cols - 4)) ]] && box_w=$((cols - 4))
    pad=$(( (cols - box_w) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    [[ -z "${pad:-}" ]] && pad=0

    # ── Clear and draw banner (no vertical centering — main screen) ──
    tput clear 2>/dev/null || printf '\x1b[2J\x1b[H' 2>/dev/null
    printf '\n'  # single top margin

    printf '%*s%s╔' "$pad" "" "$(green)"
    local i
    for ((i = 0; i < box_w - 2; i++)); do printf '═'; done
    printf '╗%s\n' "$(reset)"

    printf '%*s%s║%s  %s[>_]%s SCREEN-TUI v5.1 — GNU Screen Session Manager' \
        "$pad" "" "$(green)" "$(reset)" "$(green)" "$(dim)"
    local title_text="  [>_] SCREEN-TUI v5.1 — GNU Screen Session Manager"
    local fill=$((box_w - ${#title_text} - 3))
    [[ $fill -gt 0 ]] && printf '%*s' "$fill" ""
    printf ' %s║%s\n' "$(green)" "$(reset)"

    printf '%*s%s║%s  %smade by Experience (DTK)' \
        "$pad" "" "$(green)" "$(reset)" "$(dim)"
    local credit_text="  made by Experience (DTK)"
    local credit_fill=$((box_w - ${#credit_text} - 3))
    [[ $credit_fill -gt 0 ]] && printf '%*s' "$credit_fill" ""
    printf ' %s║%s\n' "$(green)" "$(reset)"

    printf '%*s%s╚' "$pad" "" "$(green)"
    for ((i = 0; i < box_w - 2; i++)); do printf '═'; done
    printf '╝%s\n' "$(reset)"

    # ── "No sessions" message (centered with banner) ──
    printf '%*s%s  ●  %sNo active screen sessions found.%s\n' \
        "$pad" "" "$(yellow)" "$(white)" "$(reset)"

    # ── Status line (centered with banner) ──
    printf '%*s%s  system ready%s  │  %s%s sessions%s  │  %s%s%s%s\n\n' \
        "$pad" "" "$(dim)" "$(reset)" "$(dim)" "$(red)" "$(dim)" "$(reset)" \
        "$(dim)" "$(date +%H:%M:%S)" "$(reset)"

    # ── Prompt (centered to match banner text at pad+3) ──
    local prompt_line="Enter session name:"
    local custom_name
    # Build separator matching banner internal width (box_w - 2)
    local sep=''
    local si
    for ((si = 0; si < box_w - 2; si++)); do sep+='═'; done

    # ── Loop until user enters a valid name ──
    while true; do
        printf '%*s\x1b[1;36m%s\x1b[0m\n' "$pad" "" "$sep"
        printf '%*s   %s' "$pad" "" "$prompt_line"
        printf '\n'
        printf '%*s\x1b[1;36m%s\x1b[0m\n' "$pad" "" "$sep"
        printf '\n'
        printf '%*s   \x1b[1;32m' "$pad" ""

        IFS= read -r custom_name
        printf '\x1b[0m\n'

        # ── Reject empty input ──
        if [[ -z "$custom_name" ]]; then
            printf '%*s\x1b[1;31m   ERROR: Session name cannot be empty.\x1b[0m\n\n' "$pad" ""
            continue
        fi

        # ── Validate: no spaces, no slashes ──
        if [[ "$custom_name" =~ [[:space:]/] ]]; then
            printf '%*s\x1b[1;31m   ERROR: Session name cannot contain spaces or slashes.\x1b[0m\n\n' "$pad" ""
            continue
        fi

        break
    done

    # ── Create and attach to new screen session ──
    printf '%*s\x1b[1;33m   Launching screen session: %s ...\x1b[0m\n' "$pad" "" "$custom_name"
    sleep 0.3

    if "$SCREEN_BIN" -S "$custom_name"; then
        exec "$0"
    else
        printf '\n\x1b[1;31mERROR: Failed to create screen session "%s"\x1b[0m\n' "${custom_name:0:40}" >&2
        printf 'Check that GNU Screen is installed and functioning.\n' >&2
        printf 'Press Enter to exit...' >&2
        read -r _ 2>/dev/null || true
        exit 1
    fi
}

# =============================================================================
# handle_menu_input() — Handle key presses in menu mode (Phase 2 + Phase 4)
# Improvements:
#   - Wrap-around: up at top → bottom, down at bottom → top
#   - 'h' opens help screen
#   - 'r' shows rename info message (Phase 4)
#   - F5 / Ctrl+L refreshes session list (Phase 4)
#   - 'q' shows goodbye message on exit (Phase 4)
#   - Sets needs_render flag when state changes (performance optimization)
# =============================================================================
handle_menu_input() {
    local key
    key=$(read_key) || {
        # read_key failed (EOF) → safe exit
        cleanup
    }

    case "$key" in
        # ── Up arrow (↑): ESC [ A or ESC O A ──
        $'\x1b[A'|$'\x1bOA')
            if [[ $cursor -gt 0 ]]; then
                cursor=$((cursor - 1))
            else
                # Wrap-around: up at top → go to bottom of list
                cursor=$((${#SESSIONS[@]} - 1))
            fi
            needs_render=true
            ;;

        # ── Down arrow (↓): ESC [ B or ESC O B ──
        $'\x1b[B'|$'\x1bOB')
            if [[ $cursor -lt $((${#SESSIONS[@]} - 1)) ]]; then
                cursor=$((cursor + 1))
            else
                # Wrap-around: down at bottom → go to top of list
                cursor=0
            fi
            needs_render=true
            ;;

        # ── Enter: attach to selected session ──
        '')
            attach_session
            ;;

        # ── q or Q or Ctrl+X (\x18): clean quit with goodbye message ──
        q|Q|$'\x18')
            show_goodbye=true
            cleanup
            ;;

        # ── n or N: create new session (Phase 4 enhanced) ──
        n|N)
            create_new_session
            ;;

        # ── x or X: kill session (with confirmation) ──
        x|X)
            kill_session
            needs_render=true
            ;;

        # ── h or H: open help screen ──
        h|H)
            help_from_mode="menu"
            mode="help"
            needs_render=true
            ;;

        # ── F5 (ESC[15~) or Ctrl+L (\x0c): refresh session list ──
        $'\x1b[15~'|$'\x0c')
            refresh_sessions
            ;;

        # ── Other keys — ignore (no re-render needed, saves CPU) ──
        *)
            ;;
    esac
}

# =============================================================================
# check_screen_installed() — Verify screen is installed and show error if not
# Returns 0 if installed; displays error + waits for q if not installed.
# =============================================================================
check_screen_installed() {
    if ! $SCREEN_AVAILABLE; then
        # Display error message about missing screen
        printf '\x1b[1;31m'  # Bold red
        printf '══════════════════════════════════════════════════════\n'
        printf '  ERROR: GNU Screen is not installed                   \n'
        printf '══════════════════════════════════════════════════════\n'
        printf '\x1b[0m'
        printf '\n'
        printf '  Please install screen:\n'
        printf '    Debian/Ubuntu:  sudo apt install screen\n'
        printf '    Arch Linux:     sudo pacman -S screen\n'
        printf '    Fedora:         sudo dnf install screen\n'
        printf '\n'
        printf '  \x1b[1mq\x1b[0m — Quit\n'
        printf '\n'

        # Read key from user
        local key
        while true; do
            IFS= read -rsn1 key 2>/dev/null || { printf '\n'; exit 1; }
            case "$key" in
                q|Q) printf '\n'; exit 0 ;;
                *) ;;
            esac
        done
    fi
    return 0
}

# =============================================================================
# terminal_size_ok() — Check terminal is large enough for TUI (Phase 4)
# Minimum: 10 lines height, 40 columns width.
# Returns 0 if OK, 1 if too small (with error message).
# =============================================================================
terminal_size_ok() {
    local lines cols
    lines=$(tput lines 2>/dev/null || echo 24)
    cols=$(tput cols 2>/dev/null || echo 80)

    local ok=true
    if [[ $lines -lt 10 ]]; then
        printf '\x1b[1;31mERROR: Terminal too small.\x1b[0m\n' >&2
        printf '  Current height: %d lines (minimum: 10)\n' "$lines" >&2
        ok=false
    fi
    if [[ $cols -lt 40 ]]; then
        printf '\x1b[1;31mERROR: Terminal too small.\x1b[0m\n' >&2
        printf '  Current width: %d columns (minimum: 40)\n' "$cols" >&2
        ok=false
    fi

    if ! $ok; then
        printf '\nPlease resize your terminal and try again.\n' >&2
        return 1
    fi
    return 0
}

# =============================================================================
# refresh_sessions() — Manually refresh session list (Phase 4)
# Re-parses screen -ls output and marks UI for re-render.
# Handles transition between menu and empty states.
# =============================================================================
refresh_sessions() {
    parse_screen_list
    if [[ ${#SESSIONS[@]} -eq 0 ]]; then
        mode="empty"
        cursor=0
    else
        mode="menu"
        # Clamp cursor to valid range
        if [[ $cursor -ge ${#SESSIONS[@]} ]]; then
            cursor=$((${#SESSIONS[@]} - 1))
        fi
    fi
    needs_render=true
}

# =============================================================================
# show_version() — Print version and exit (Phase 4)
# =============================================================================
show_version() {
    echo "screen-tui version 5.1.0"
    echo "Pure Bash TUI for GNU Screen session management."
}

# =============================================================================
# show_usage() — Print usage/help and exit (Phase 4)
# =============================================================================
show_usage() {
    cat << 'USAGEEOF'
Usage: screen-tui [OPTIONS]

A Terminal User Interface for managing GNU Screen sessions.

Options:
  --help, -h      Show this help message and exit
  --version, -V   Show version information and exit

Keyboard Shortcuts (inside TUI):
  ↑/↓             Navigate session list
  Enter           Attach to selected session
  n               Create new session (prompts for name)
  x               Kill selected session (with confirmation)
  F5 / Ctrl+L     Refresh session list
  q / Ctrl+X      Quit (return to terminal)
  h               Show help overlay
  Ctrl+C          Exit immediately

Description:
  screen-tui provides a full-screen interface for managing GNU Screen
  sessions. On login/SSH, it automatically displays your screen sessions.
  If no sessions exist, it prompts you to create one.

  This script is designed to be auto-launched from ~/.zshrc or ~/.bashrc
  so that screen sessions are always available on login.

Report issues: https://github.com/example/screen-tui
USAGEEOF
}

# =============================================================================
# main() — Entry point (Phase 2 + Phase 4)
# Improvements:
#   - Only renders when state changes (needs_render=true) — CPU optimization
#   - Still renders immediately on SIGWINCH (terminal resize)
#   - Phase 4: CLI flags (--version, --help), terminal size check
#   - Branches to help mode input handling separately
# =============================================================================
main() {
    # ── Step 0: Handle CLI flags (before any terminal setup) ──
    case "${1:-}" in
        --version|-V)
            show_version
            exit 0
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        "")
            # No args, proceed to TUI
            ;;
        -*)
            echo "screen-tui: unknown option: $1" >&2
            echo "Try 'screen-tui --help' for more information." >&2
            exit 1
            ;;
    esac

    # ── Step 0.5: Check terminal size ──
    terminal_size_ok || exit 1

    # ── Step 1: Check screen is installed ──
    check_screen_installed

    # ── Step 2: Configure terminal (alternate buffer, hide cursor) ──
    setup_terminal

    # ── Step 3: Register trap handlers ──
    # SIGINT (Ctrl+C), SIGTERM → cleanup
    trap cleanup SIGINT SIGTERM
    # SIGWINCH (terminal resize) → redraw immediately
    # Set needs_render=false after drawing to avoid double-render in main loop
    trap 'render_ui; needs_render=false' SIGWINCH

    # ── Step 4: Parse current screen session list ──
    parse_screen_list

    # ── Step 5: Branch — empty state or menu ──
    if [[ ${#SESSIONS[@]} -eq 0 ]]; then
        # No sessions → show empty screen and wait for new session creation
        handle_empty_state
    else
        # Has sessions → enter main menu loop
        mode="menu"
        needs_render=true
        while true; do
            # Only render when state has changed (performance optimization)
            # Avoids re-rendering when user presses an invalid key
            if $needs_render; then
                render_ui
                needs_render=false
            fi

            # If mode is empty (after execute_kill), switch to handle_empty_state immediately
            # (handle_empty_state has its own loop, won't return here)
            if [[ "$mode" == "empty" ]]; then
                handle_empty_state
            fi

            # Branch input handling by current mode
            case "$mode" in
                help)
                    handle_help_input
                    ;;
                confirm_kill|confirm_kill_attached)
                    # Phase 3: Modal confirmation with ← → Enter Esc
                    handle_confirm_input
                    ;;
                *)
                    handle_menu_input
                    ;;
            esac

            # If after processing a key the list is empty, switch to empty state
            if [[ ${#SESSIONS[@]} -eq 0 ]]; then
                handle_empty_state
            fi
        done
    fi

    # ── Final cleanup (never reached — all exit paths use exit/exec) ──
    cleanup
}

# =============================================================================
# Run main with all command-line arguments
# =============================================================================
main "$@"
