#!/bin/bash

# Sync with upstream repository
# 同步上游仓库脚本

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BRANCH="${1:-canary}"
UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
FORK_REMOTE="${FORK_REMOTE:-origin}"

print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}═══${NC} $1 ${BLUE}═══${NC}\n"
}

# Check if upstream remote exists
check_upstream() {
    if ! git remote | grep -q "^${UPSTREAM_REMOTE}$"; then
        print_error "Upstream remote '${UPSTREAM_REMOTE}' not found"
        print_info "Please add upstream remote first:"
        echo ""
        echo "  If origin points to official repo:"
        echo "    git remote rename origin upstream"
        echo "    git remote add origin https://github.com/YOUR_USERNAME/AFFiNE.git"
        echo ""
        echo "  Or add upstream directly:"
        echo "    git remote add upstream https://github.com/toeverything/AFFiNE.git"
        echo ""
        exit 1
    fi
}

# Check current status
check_status() {
    print_step "Checking Repository Status"

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "You have uncommitted changes"
        git status --short
        echo ""
        read -p "Stash changes and continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git stash save "Auto-stash before sync at $(date)"
            print_success "Changes stashed"
        else
            print_error "Please commit or stash your changes first"
            exit 1
        fi
    else
        print_success "Working directory is clean"
    fi

    # Show current branch
    CURRENT_BRANCH=$(git branch --show-current)
    print_info "Current branch: $CURRENT_BRANCH"

    if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
        print_warning "Not on $BRANCH branch"
        read -p "Switch to $BRANCH? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git checkout "$BRANCH"
            print_success "Switched to $BRANCH"
        else
            print_info "Continuing on $CURRENT_BRANCH"
            BRANCH=$CURRENT_BRANCH
        fi
    fi
}

# Fetch upstream updates
fetch_upstream() {
    print_step "Fetching Upstream Updates"

    print_info "Fetching from ${UPSTREAM_REMOTE}..."
    git fetch "$UPSTREAM_REMOTE"

    # Show what's new
    COMMITS_BEHIND=$(git rev-list --count HEAD..${UPSTREAM_REMOTE}/${BRANCH} 2>/dev/null || echo "0")

    if [ "$COMMITS_BEHIND" -eq "0" ]; then
        print_success "Already up to date with upstream"
        exit 0
    else
        print_info "Your branch is behind upstream by $COMMITS_BEHIND commits"
        echo ""
        print_info "New commits:"
        git log --oneline --graph HEAD..${UPSTREAM_REMOTE}/${BRANCH} | head -10
        echo ""
    fi
}

# Sync with upstream
sync() {
    print_step "Syncing with Upstream"

    read -p "Continue with rebase? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Sync cancelled"
        exit 0
    fi

    print_info "Rebasing onto ${UPSTREAM_REMOTE}/${BRANCH}..."

    if git rebase "${UPSTREAM_REMOTE}/${BRANCH}"; then
        print_success "Rebase completed successfully"
    else
        print_error "Rebase failed - conflicts need to be resolved"
        print_info "To resolve conflicts:"
        echo "  1. Fix conflicts in the listed files"
        echo "  2. git add <resolved-files>"
        echo "  3. git rebase --continue"
        echo ""
        echo "To abort rebase:"
        echo "  git rebase --abort"
        exit 1
    fi
}

# Push to fork
push_to_fork() {
    print_step "Pushing to Fork"

    # Check if fork remote exists
    if ! git remote | grep -q "^${FORK_REMOTE}$"; then
        print_warning "Fork remote '${FORK_REMOTE}' not found"
        print_info "Skipping push to fork"
        return
    fi

    print_info "Pushing to ${FORK_REMOTE}/${BRANCH}..."
    read -p "Push changes to your fork? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if git push "$FORK_REMOTE" "$BRANCH" --force-with-lease; then
            print_success "Successfully pushed to fork"
        else
            print_warning "Push failed - you may need to push manually"
        fi
    else
        print_info "Skipped pushing to fork"
        print_warning "Remember to push later: git push $FORK_REMOTE $BRANCH --force-with-lease"
    fi
}

# Show summary
show_summary() {
    print_step "Sync Complete!"

    print_info "Current status:"
    git log --oneline --graph -5

    echo ""
    print_info "What's next:"
    echo "  - If you have a fork, remember to push: git push $FORK_REMOTE $BRANCH --force-with-lease"
    echo "  - Check for any new dependencies: yarn install"
    echo "  - Restart your development servers if running"
}

# Main script
main() {
    print_info "Upstream Sync Script"
    print_info "Branch: $BRANCH"
    print_info "Upstream: $UPSTREAM_REMOTE"
    print_info "Fork: $FORK_REMOTE"
    echo ""

    check_upstream
    check_status
    fetch_upstream
    sync
    push_to_fork
    show_summary
}

# Show help
if [ "${1:-}" = "help" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0 [BRANCH]"
    echo ""
    echo "Sync local branch with upstream repository"
    echo ""
    echo "Arguments:"
    echo "  BRANCH      Branch to sync (default: canary)"
    echo ""
    echo "Environment variables:"
    echo "  UPSTREAM_REMOTE    Upstream remote name (default: upstream)"
    echo "  FORK_REMOTE        Fork remote name (default: origin)"
    echo ""
    echo "Examples:"
    echo "  $0              # Sync canary branch"
    echo "  $0 main         # Sync main branch"
    echo "  UPSTREAM_REMOTE=origin $0  # Use origin as upstream"
    exit 0
fi

# Run main function
main "$@"
