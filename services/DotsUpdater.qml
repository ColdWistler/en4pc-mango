pragma Singleton

import qs
import QtQuick
import Quickshell

Singleton {
    id: root

    function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "if type -q yay; yay -Syu --combinedupgrade=false; else if type -q paru; paru -Syu; else; sudo pacman -Syu; end"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    /**
     * Updates this config in place from YOUR fork (origin).
     *
     * The upstream implementation cloned pctrade/end4-pC over the top of this
     * directory and deleted the previous clone, which destroyed the MangoWM
     * port and every local branch/remote. For a fork, this repo is the source
     * of truth and upstream is only a supplier, so an in-place fast-forward is
     * the safe equivalent:
     *
     *   - never deletes or replaces the repo directory
     *   - refuses to run on a dirty working tree
     *   - only ever fast-forwards, so no surprise merges or history rewrites
     *   - quickshell reloads changed QML itself, so no restart is needed
     *
     * Files changed on disk are picked up by the running shell automatically.
     */
    function runUpdateDots() {
        const updateScript = `
            set -u
            REPO="$HOME/.config/quickshell/end4-pC"
            echo "end4-pC: updating from your fork (origin)"
            echo

            if [ ! -d "$REPO/.git" ]; then
                echo "Not a git clone: $REPO" >&2
                exit 1
            fi
            cd "$REPO" 2>/dev/null || exit 1

            if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
                echo "Working tree has local changes - commit or stash them first:" >&2
                git status --short | head -10
                exit 1
            fi

            BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)
            if [ -z "$BRANCH" ]; then
                echo "Detached HEAD. Check out a branch first:" >&2
                echo "  git checkout $BRANCH" >&2
                exit 1
            fi

            if [ -z "$(git remote 2>/dev/null | grep -x origin)" ]; then
                echo "No 'origin' remote configured, so there is nothing to update from." >&2
                echo "Add one with:  git remote add origin <your-fork-url>" >&2
                exit 1
            fi

            echo "-- git fetch --all --"
            git fetch --all || { echo "fetch failed (offline?)" >&2; exit 1; }
            echo

            echo "-- git pull --ff-only origin $BRANCH --"
            if git pull --ff-only origin "$BRANCH"; then
                echo
                echo "Done: $BRANCH is now at $(git rev-parse --short HEAD)."
                echo "The shell reloads changed files on its own."
                echo
                echo "Upstream pctrade/end4-pC is ahead of you by $(git rev-list --count HEAD..upstream/main 2>/dev/null || echo '?') commit(s)."
                echo "To review them before touching your tree:"
                echo "  git log --oneline HEAD..upstream/main"
                echo "To pull them in, test in a worktree first, then:"
                echo "  git merge upstream/main && git push"
            else
                echo
                echo "Fast-forward refused: $BRANCH has commits that are not on origin yet." >&2
                echo "Push them (git push) or merge deliberately after testing - nothing was changed." >&2
                exit 1
            fi
        `

        Quickshell.execDetached(["kitty", "--hold", "bash", "-c", updateScript])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }
}
