#!/bin/bash

# Setup Fork Workflow
# 配置 Fork 工作流

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FORK_URL="${FORK_URL:-https://github.com/pepsing/AFFiNE.git}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/toeverything/AFFiNE}"

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

# Show current status
show_current_status() {
    print_step "Current Remote Configuration"

    print_info "Current remotes:"
    git remote -v

    echo ""
    print_info "Current branch:"
    git branch --show-current

    echo ""
    print_info "Unpushed commits:"
    git log --oneline origin/canary..HEAD 2>/dev/null || echo "  (unable to compare with origin)"
}

# Backup current config
backup_config() {
    print_step "Backing Up Current Configuration"

    git remote -v > .git-remotes.backup
    print_success "Backed up to .git-remotes.backup"
}

# Reconfigure remotes
reconfigure_remotes() {
    print_step "Reconfiguring Remotes"

    # Check if upstream already exists
    if git remote | grep -q "^upstream$"; then
        print_warning "Remote 'upstream' already exists"
        read -p "Remove and reconfigure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git remote remove upstream
            print_success "Removed old 'upstream'"
        else
            print_info "Keeping existing 'upstream'"
            return
        fi
    fi

    # Rename origin to upstream
    print_info "Renaming 'origin' to 'upstream'..."
    git remote rename origin upstream
    print_success "Renamed origin → upstream"

    # Add your fork as origin
    print_info "Adding your fork as 'origin'..."
    git remote add origin "$FORK_URL"
    print_success "Added origin → $FORK_URL"

    echo ""
    print_info "New remote configuration:"
    git remote -v
}

# Push to fork
push_to_fork() {
    print_step "Pushing to Your Fork"

    CURRENT_BRANCH=$(git branch --show-current)
    print_info "Current branch: $CURRENT_BRANCH"

    # Check if there are unpushed commits
    UNPUSHED=$(git log --oneline upstream/$CURRENT_BRANCH..HEAD 2>/dev/null | wc -l | tr -d ' ')

    if [ "$UNPUSHED" -gt 0 ]; then
        print_info "You have $UNPUSHED unpushed commit(s):"
        git log --oneline upstream/$CURRENT_BRANCH..HEAD
        echo ""
    fi

    read -p "Push $CURRENT_BRANCH to your fork? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Pushing to origin/$CURRENT_BRANCH..."

        # Try normal push first
        if git push origin "$CURRENT_BRANCH" 2>/dev/null; then
            print_success "Pushed successfully"
        else
            print_warning "Normal push failed, trying force-with-lease..."
            if git push origin "$CURRENT_BRANCH" --force-with-lease; then
                print_success "Force pushed successfully"
            else
                print_error "Push failed"
                print_info "You may need to manually push later:"
                echo "  git push origin $CURRENT_BRANCH --force-with-lease"
            fi
        fi
    else
        print_info "Skipped push"
        print_warning "Remember to push later:"
        echo "  git push origin $CURRENT_BRANCH --force-with-lease"
    fi
}

# Verify setup
verify_setup() {
    print_step "Verifying Setup"

    # Check upstream
    if git remote | grep -q "^upstream$"; then
        UPSTREAM_URL_ACTUAL=$(git remote get-url upstream)
        if [[ $UPSTREAM_URL_ACTUAL == *"toeverything/AFFiNE"* ]]; then
            print_success "Upstream configured correctly: $UPSTREAM_URL_ACTUAL"
        else
            print_error "Upstream URL incorrect: $UPSTREAM_URL_ACTUAL"
        fi
    else
        print_error "Upstream remote not found"
    fi

    # Check origin
    if git remote | grep -q "^origin$"; then
        ORIGIN_URL_ACTUAL=$(git remote get-url origin)
        if [[ $ORIGIN_URL_ACTUAL == *"pepsing/AFFiNE"* ]]; then
            print_success "Origin configured correctly: $ORIGIN_URL_ACTUAL"
        else
            print_warning "Origin URL: $ORIGIN_URL_ACTUAL"
        fi
    else
        print_error "Origin remote not found"
    fi

    echo ""
    print_info "Testing connectivity..."

    # Test upstream
    if git ls-remote upstream HEAD > /dev/null 2>&1; then
        print_success "Can connect to upstream"
    else
        print_warning "Cannot connect to upstream (network issue?)"
    fi

    # Test origin
    if git ls-remote origin HEAD > /dev/null 2>&1; then
        print_success "Can connect to origin (your fork)"
    else
        print_warning "Cannot connect to origin (authentication issue?)"
    fi
}

# Show next steps
show_next_steps() {
    print_step "Setup Complete!"

    echo ""
    print_success "Fork workflow configured successfully"
    echo ""
    print_info "Remote configuration:"
    git remote -v | grep -E "^(origin|upstream)"

    echo ""
    print_info "Common commands:"
    echo ""
    echo "  同步官方更新："
    echo "    ./scripts/sync-upstream.sh"
    echo ""
    echo "  推送到你的 fork："
    echo "    git push origin canary"
    echo ""
    echo "  查看远程分支："
    echo "    git branch -r"
    echo ""
    echo "  查看所有 remote："
    echo "    git remote -v"
    echo ""

    print_info "Documentation:"
    echo "  详细工作流: docs/FORK_WORKFLOW.md"
}

# Main script
main() {
    print_info "Fork Workflow Setup Script"
    print_info "Fork URL: $FORK_URL"
    print_info "Upstream URL: $UPSTREAM_URL"
    echo ""

    show_current_status

    echo ""
    read -p "Continue with setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Setup cancelled"
        exit 0
    fi

    backup_config
    reconfigure_remotes
    verify_setup
    push_to_fork
    show_next_steps
}

# Show help
if [ "${1:-}" = "help" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0"
    echo ""
    echo "Setup fork workflow for AFFiNE development"
    echo ""
    echo "This script will:"
    echo "  1. Rename 'origin' to 'upstream' (official repo)"
    echo "  2. Add your fork as 'origin'"
    echo "  3. Push your local commits to fork"
    echo "  4. Verify configuration"
    echo ""
    echo "Environment variables:"
    echo "  FORK_URL       Your fork URL (default: https://github.com/pepsing/AFFiNE.git)"
    echo "  UPSTREAM_URL   Upstream URL (default: https://github.com/toeverything/AFFiNE)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use defaults"
    echo "  FORK_URL=git@github.com:pepsing/AFFiNE.git $0  # Use SSH"
    exit 0
fi

# Run main function
main "$@"
