#!/usr/bin/env bash
set -euo pipefail

# OGP Project Dependency Provisioning Script
# This script is idempotent - safe to run multiple times
# It will check for existing dependencies and only install if needed

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Dependency versions
BAZEL_VERSION="7.0.0"
REQUIRED_CPP_STANDARD=17

echo "=== OGP Project Dependency Provisioning ==="
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
echo "Detected OS: $OS"
echo ""

# Function to compare version numbers
version_ge() {
    # Returns 0 (true) if $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Check and install Homebrew (macOS only)
if [[ "$OS" == "macos" ]]; then
    echo "Checking Homebrew..."
    if command -v brew &> /dev/null; then
        BREW_VERSION=$(brew --version | head -n1 | awk '{print $2}')
        echo -e "${GREEN}✓${NC} Homebrew is installed (version $BREW_VERSION)"
    else
        echo -e "${YELLOW}→${NC} Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo -e "${GREEN}✓${NC} Homebrew installed"
    fi
    echo ""
fi

# Check and install Bazel
echo "Checking Bazel..."
if command -v bazel &> /dev/null; then
    CURRENT_BAZEL_VERSION=$(bazel --version | awk '{print $2}')
    echo "Current Bazel version: $CURRENT_BAZEL_VERSION"
    
    if version_ge "$CURRENT_BAZEL_VERSION" "$BAZEL_VERSION"; then
        echo -e "${GREEN}✓${NC} Bazel $CURRENT_BAZEL_VERSION is installed (required: $BAZEL_VERSION)"
    else
        echo -e "${YELLOW}→${NC} Bazel $CURRENT_BAZEL_VERSION is older than required $BAZEL_VERSION"
        echo "   Upgrading Bazel..."
        if [[ "$OS" == "macos" ]]; then
            brew upgrade bazel
        elif [[ "$OS" == "linux" ]]; then
            # Install Bazelisk which manages Bazel versions
            sudo wget -O /usr/local/bin/bazel https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
            sudo chmod +x /usr/local/bin/bazel
        fi
        echo -e "${GREEN}✓${NC} Bazel upgraded"
    fi
else
    echo -e "${YELLOW}→${NC} Installing Bazel $BAZEL_VERSION..."
    if [[ "$OS" == "macos" ]]; then
        brew install bazel
    elif [[ "$OS" == "linux" ]]; then
        # Install Bazelisk which manages Bazel versions
        sudo wget -O /usr/local/bin/bazel https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
        sudo chmod +x /usr/local/bin/bazel
    fi
    echo -e "${GREEN}✓${NC} Bazel installed"
fi
echo ""

# Check C++ compiler (require Clang)
echo "Checking C++ compiler..."
CXX_FOUND=false
CXX_NAME="clang++"
CXX_VERSION=""

# Check for clang++
if command -v clang++ &> /dev/null; then
    CXX_VERSION=$(clang++ --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    
    # Check C++17 support
    if clang++ -std=c++17 -x c++ -E - < /dev/null &> /dev/null; then
        echo -e "${GREEN}✓${NC} Clang++ $CXX_VERSION is installed with C++$REQUIRED_CPP_STANDARD support"
        CXX_FOUND=true
    else
        echo -e "${RED}✗${NC} Clang++ $CXX_VERSION does not support C++$REQUIRED_CPP_STANDARD"
        echo "Please install a newer version of Clang with C++17 support"
        CXX_FOUND=false
    fi
else
    echo -e "${YELLOW}→${NC} Clang++ not found. Installing..."
    if [[ "$OS" == "macos" ]]; then
        # On macOS, Clang comes with Xcode Command Line Tools
        xcode-select --install 2>/dev/null || true
        echo "Waiting for Xcode Command Line Tools installation..."
        echo "Please complete the installation dialog if it appears."
        # Wait for installation to complete
        until xcode-select -p &> /dev/null; do
            sleep 5
        done
        echo -e "${GREEN}✓${NC} Xcode Command Line Tools installed"
        
        # Verify clang++ is now available
        if command -v clang++ &> /dev/null; then
            CXX_VERSION=$(clang++ --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            echo -e "${GREEN}✓${NC} Clang++ $CXX_VERSION is now available"
            CXX_FOUND=true
        fi
    elif [[ "$OS" == "linux" ]]; then
        sudo apt-get update
        sudo apt-get install -y clang
        echo -e "${GREEN}✓${NC} Clang installed"
        
        # Verify clang++ is now available
        if command -v clang++ &> /dev/null; then
            CXX_VERSION=$(clang++ --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            echo -e "${GREEN}✓${NC} Clang++ $CXX_VERSION is now available"
            CXX_FOUND=true
        fi
    fi
fi
echo ""

# Check Git
echo "Checking Git..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    echo -e "${GREEN}✓${NC} Git $GIT_VERSION is installed"
else
    echo -e "${YELLOW}→${NC} Installing Git..."
    if [[ "$OS" == "macos" ]]; then
        brew install git
    elif [[ "$OS" == "linux" ]]; then
        sudo apt-get install -y git
    fi
    echo -e "${GREEN}✓${NC} Git installed"
fi
echo ""

# Verify all dependencies
echo "=== Dependency Verification ==="
echo ""

ALL_GOOD=true

if command -v bazel &> /dev/null; then
    echo -e "${GREEN}✓${NC} Bazel: $(bazel --version)"
else
    echo -e "${RED}✗${NC} Bazel: NOT FOUND"
    ALL_GOOD=false
fi

if [[ "$CXX_FOUND" == true ]]; then
    echo -e "${GREEN}✓${NC} C++ Compiler: Clang++ $CXX_VERSION"
else
    echo -e "${RED}✗${NC} C++ Compiler: Clang++ NOT FOUND"
    ALL_GOOD=false
fi

if command -v git &> /dev/null; then
    echo -e "${GREEN}✓${NC} Git: $(git --version | awk '{print $3}')"
else
    echo -e "${RED}✗${NC} Git: NOT FOUND"
    ALL_GOOD=false
fi

echo ""

if [[ "$ALL_GOOD" == true ]]; then
    echo -e "${GREEN}=== All dependencies are installed and ready! ===${NC}"
    echo ""
    echo "You can now build the project with:"
    echo "  bazel build //..."
    echo ""
    echo "Run the server with:"
    echo "  bazel run //src/server:server"
    echo ""
    echo "Run the client with:"
    echo "  bazel run //src/client:client"
    exit 0
else
    echo -e "${RED}=== Some dependencies are missing ===${NC}"
    echo "Please check the errors above and try running this script again."
    exit 1
fi
