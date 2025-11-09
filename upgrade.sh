#!/usr/bin/env bash
set -euo pipefail

# OGP Project Dependency Upgrade Script
# This script attempts to upgrade dependencies one by one and tests the build
# It will rollback if tests fail after an upgrade

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== OGP Project Dependency Upgrade ==="
echo ""

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    echo -e "${RED}Error: Unsupported OS: $OSTYPE${NC}"
    exit 1
fi

# Track upgrades
UPGRADES_SUCCESSFUL=0
UPGRADES_FAILED=0
declare -a FAILED_UPGRADES

# Function to run tests
run_tests() {
    echo -e "${BLUE}→${NC} Running tests..."
    if bazel test //... 2>&1; then
        echo -e "${GREEN}✓${NC} Tests passed"
        return 0
    else
        echo -e "${RED}✗${NC} Tests failed"
        return 1
    fi
}

# Function to build project
build_project() {
    echo -e "${BLUE}→${NC} Building project..."
    if bazel build //... 2>&1; then
        echo -e "${GREEN}✓${NC} Build successful"
        return 0
    else
        echo -e "${RED}✗${NC} Build failed"
        return 1
    fi
}

# Pre-flight check: ensure project builds and tests pass
echo "=== Pre-flight Check ==="
echo ""
if ! build_project; then
    echo -e "${RED}Error: Project does not build before upgrades${NC}"
    echo "Please fix build errors before running upgrade script."
    exit 1
fi

if ! run_tests; then
    echo -e "${YELLOW}Warning: Tests are failing before upgrades${NC}"
    echo "Continuing anyway, but upgrades may not be reliable."
fi

echo ""
echo "=== Starting Dependency Upgrades ==="
echo ""

# Upgrade Bazel (if using Homebrew on macOS)
if [[ "$OS" == "macos" ]] && command -v brew &> /dev/null; then
    echo "--- Upgrading Bazel ---"
    BAZEL_OLD_VERSION=$(bazel --version 2>/dev/null | awk '{print $2}' || echo "unknown")
    echo "Current Bazel version: $BAZEL_OLD_VERSION"
    
    if brew upgrade bazel 2>&1 | grep -q "already installed"; then
        echo -e "${GREEN}✓${NC} Bazel is already at the latest version"
    else
        BAZEL_NEW_VERSION=$(bazel --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        echo "Upgraded Bazel from $BAZEL_OLD_VERSION to $BAZEL_NEW_VERSION"
        
        # Test the build
        if build_project && run_tests; then
            echo -e "${GREEN}✓${NC} Bazel upgrade successful"
            UPGRADES_SUCCESSFUL=$((UPGRADES_SUCCESSFUL + 1))
            
            # Update provision.sh with new version
            if [[ -f provision.sh ]]; then
                sed -i.bak "s/BAZEL_VERSION=\".*\"/BAZEL_VERSION=\"$BAZEL_NEW_VERSION\"/" provision.sh
                rm -f provision.sh.bak
                echo -e "${GREEN}✓${NC} Updated provision.sh with Bazel $BAZEL_NEW_VERSION"
            fi
        else
            echo -e "${RED}✗${NC} Bazel upgrade broke the build"
            UPGRADES_FAILED=$((UPGRADES_FAILED + 1))
            FAILED_UPGRADES+=("Bazel ($BAZEL_OLD_VERSION -> $BAZEL_NEW_VERSION)")
            
            # Rollback
            echo -e "${YELLOW}→${NC} Rolling back Bazel..."
            if command -v brew &> /dev/null; then
                brew uninstall bazel
                brew install bazel@$BAZEL_OLD_VERSION || brew install bazel
            fi
            echo -e "${YELLOW}✓${NC} Rolled back Bazel"
        fi
    fi
    echo ""
fi

# Upgrade C++ compiler (if using Homebrew on macOS)
if [[ "$OS" == "macos" ]] && command -v brew &> /dev/null; then
    # Check if llvm is installed via brew
    if brew list llvm &> /dev/null; then
        echo "--- Upgrading LLVM/Clang ---"
        LLVM_OLD_VERSION=$(brew list --versions llvm | awk '{print $2}')
        echo "Current LLVM version: $LLVM_OLD_VERSION"
        
        if brew upgrade llvm 2>&1 | grep -q "already installed"; then
            echo -e "${GREEN}✓${NC} LLVM is already at the latest version"
        else
            LLVM_NEW_VERSION=$(brew list --versions llvm | awk '{print $2}')
            echo "Upgraded LLVM from $LLVM_OLD_VERSION to $LLVM_NEW_VERSION"
            
            # Test the build
            if build_project && run_tests; then
                echo -e "${GREEN}✓${NC} LLVM upgrade successful"
                UPGRADES_SUCCESSFUL=$((UPGRADES_SUCCESSFUL + 1))
            else
                echo -e "${RED}✗${NC} LLVM upgrade broke the build"
                UPGRADES_FAILED=$((UPGRADES_FAILED + 1))
                FAILED_UPGRADES+=("LLVM ($LLVM_OLD_VERSION -> $LLVM_NEW_VERSION)")
                
                # Rollback
                echo -e "${YELLOW}→${NC} Rolling back LLVM..."
                brew uninstall llvm
                brew install llvm@$LLVM_OLD_VERSION || brew install llvm
                echo -e "${YELLOW}✓${NC} Rolled back LLVM"
            fi
        fi
        echo ""
    fi
fi

# Update all Homebrew packages (macOS)
if [[ "$OS" == "macos" ]] && command -v brew &> /dev/null; then
    echo "--- Checking for other Homebrew updates ---"
    OUTDATED=$(brew outdated | grep -v "bazel\|llvm" || true)
    if [[ -n "$OUTDATED" ]]; then
        echo "Other outdated packages:"
        echo "$OUTDATED"
        echo ""
        echo -e "${YELLOW}Note:${NC} Not automatically upgrading these packages."
        echo "Run 'brew upgrade' manually to upgrade all packages."
    else
        echo -e "${GREEN}✓${NC} All other Homebrew packages are up to date"
    fi
    echo ""
fi

# Clean Bazel cache to ensure fresh builds
echo "--- Cleaning Bazel cache ---"
bazel clean --expunge
echo -e "${GREEN}✓${NC} Bazel cache cleaned"
echo ""

# Final verification
echo "=== Final Verification ==="
echo ""
if build_project && run_tests; then
    echo -e "${GREEN}✓${NC} Final build and tests passed"
else
    echo -e "${RED}✗${NC} Final build and tests failed"
fi
echo ""

# Summary
echo "=== Upgrade Summary ==="
echo ""
echo -e "Successful upgrades: ${GREEN}$UPGRADES_SUCCESSFUL${NC}"
echo -e "Failed upgrades: ${RED}$UPGRADES_FAILED${NC}"

if [[ $UPGRADES_FAILED -gt 0 ]]; then
    echo ""
    echo "Failed upgrades (rolled back):"
    for upgrade in "${FAILED_UPGRADES[@]}"; do
        echo "  - $upgrade"
    done
fi

echo ""
echo "Current dependency versions:"
if command -v bazel &> /dev/null; then
    echo "  Bazel: $(bazel --version | awk '{print $2}')"
fi
if command -v clang++ &> /dev/null; then
    CLANG_VERSION=$(clang++ --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    echo "  Clang++: $CLANG_VERSION"
elif command -v g++ &> /dev/null; then
    GCC_VERSION=$(g++ --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    echo "  G++: $GCC_VERSION"
fi

echo ""
if [[ $UPGRADES_FAILED -eq 0 ]]; then
    echo -e "${GREEN}=== All upgrades completed successfully! ===${NC}"
    exit 0
else
    echo -e "${YELLOW}=== Some upgrades failed and were rolled back ===${NC}"
    exit 1
fi
