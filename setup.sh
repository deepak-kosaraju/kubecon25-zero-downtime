#!/bin/bash

# KubeCon 2025 Demo Setup Script
# This script installs all prerequisites for the Zero Downtime Migration Demo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Function to install Docker Desktop
install_docker() {
    if command_exists docker; then
        print_success "Docker is already installed: $(docker --version)"
        return 0
    fi

    print_status "Installing Docker Desktop..."
    
    OS=$(detect_os)
    case $OS in
        "macos")
            print_warning "Please install Docker Desktop manually from: https://docs.docker.com/desktop/install/mac-install/"
            print_warning "After installation, restart your terminal and run this script again."
            ;;
        "linux")
            # Install Docker on Linux
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            rm get-docker.sh
            print_success "Docker installed. Please log out and log back in for group changes to take effect."
            ;;
        *)
            print_error "Unsupported OS. Please install Docker Desktop manually."
            exit 1
            ;;
    esac
}

# Function to install kubectl
install_kubectl() {
    if command_exists kubectl; then
        print_success "kubectl is already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return 0
    fi

    print_status "Installing kubectl..."
    
    OS=$(detect_os)
    case $OS in
        "macos")
            # Install kubectl on macOS
            if command_exists brew; then
                brew install kubectl
            else
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
                chmod +x kubectl
                sudo mv kubectl /usr/local/bin/
            fi
            ;;
        "linux")
            # Install kubectl on Linux
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
            ;;
        *)
            print_error "Unsupported OS. Please install kubectl manually."
            exit 1
            ;;
    esac
    
    print_success "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# Function to install Kind
install_kind() {
    if command_exists kind; then
        print_success "Kind is already installed: $(kind version)"
        return 0
    fi

    print_status "Installing Kind..."
    
    OS=$(detect_os)
    case $OS in
        "macos")
            if command_exists brew; then
                brew install kind
            else
                curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64"
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/
            fi
            ;;
        "linux")
            curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/
            ;;
        *)
            print_error "Unsupported OS. Please install Kind manually."
            exit 1
            ;;
    esac
    
    print_success "Kind installed: $(kind version)"
}

# Function to install Helm
install_helm() {
    if command_exists helm; then
        print_success "Helm is already installed: $(helm version --short 2>/dev/null || helm version)"
        return 0
    fi

    print_status "Installing Helm..."

    OS=$(detect_os)
    case $OS in
        "macos")
            if command_exists brew; then
                brew install helm
            else
                print_warning "Please install Helm manually: brew install helm"
                print_warning "Or follow: https://helm.sh/docs/intro/install/"
            fi
            ;;
        "linux")
            # Install Helm on Linux
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
            ;;
        *)
            print_error "Unsupported OS. Please install Helm manually."
            print_warning "Follow: https://helm.sh/docs/intro/install/"
            exit 1
            ;;
    esac

    print_success "Helm installed: $(helm version --short 2>/dev/null || helm version)"
}

# Function to install siege
install_siege() {
    if command_exists siege; then
        print_success "siege is already installed: $(siege --version 2>/dev/null || echo "siege installed")"
        return 0
    fi

    print_status "Installing siege (load testing tool)..."

    OS=$(detect_os)
    case $OS in
        "macos")
            if command_exists brew; then
                brew install siege
            else
                print_warning "Please install siege manually: brew install siege"
            fi
            ;;
        "linux")
            # Install siege on Linux
            if command_exists apt-get; then
                sudo apt-get update && sudo apt-get install -y siege
            elif command_exists yum; then
                sudo yum install -y siege
            elif command_exists dnf; then
                sudo dnf install -y siege
            else
                print_warning "Please install siege manually using your package manager"
            fi
            ;;
        *)
            print_error "Unsupported OS. Please install siege manually."
            exit 1
            ;;
    esac

    print_success "siege installed: $(siege --version 2>/dev/null || echo "siege installed")"
}

# Function to verify all installations
verify_installations() {
    print_status "Verifying installations..."
    
    local all_good=true
    
    if ! command_exists docker; then
        print_error "Docker is not installed or not in PATH"
        all_good=false
    fi
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed or not in PATH"
        all_good=false
    fi
    
    if ! command_exists kind; then
        print_error "Kind is not installed or not in PATH"
        all_good=false
    fi
    
    if ! command_exists siege; then
        print_error "siege is not installed or not in PATH"
        all_good=false
    fi
    
    if ! command_exists helm; then
        print_error "Helm is not installed or not in PATH"
        all_good=false
    fi
    
    if [ "$all_good" = true ]; then
        print_success "All prerequisites are installed and ready!"
        echo ""
        echo "Next steps:"
        echo "1. Build and push the demo app: cd demo-app && docker build -t your-username/fast-api-demo-sleep:v0.1.2 ."
        echo "2. Update the image reference in monolith-migration/base-manifest/deployment.yaml"
        echo "3. Follow the README.md instructions to run the demo"
    else
        print_error "Some prerequisites are missing. Please install them manually."
        exit 1
    fi
}

# Main execution
main() {
    echo "🚀 KubeCon 2025 Demo Setup Script"
    echo "=================================="
    echo ""
    
    print_status "Detected OS: $(detect_os)"
    echo ""
    
    # Install prerequisites
    install_docker
    install_kubectl
    install_kind
    install_helm
    install_siege
    
    echo ""
    verify_installations
}

# Run main function
main "$@"
