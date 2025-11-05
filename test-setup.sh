#!/bin/bash

# KubeCon 2025 Demo Setup Test Script
# This script verifies that all prerequisites are properly installed

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

# Function to test Docker
test_docker() {
    print_status "Testing Docker..."
    if command_exists docker; then
        if docker --version >/dev/null 2>&1; then
            print_success "Docker is working: $(docker --version)"
            return 0
        else
            print_error "Docker is installed but not working properly"
            return 1
        fi
    else
        print_error "Docker is not installed"
        return 1
    fi
}

# Function to test kubectl
test_kubectl() {
    print_status "Testing kubectl..."
    if command_exists kubectl; then
        if kubectl version --client >/dev/null 2>&1; then
            print_success "kubectl is working: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
            return 0
        else
            print_error "kubectl is installed but not working properly"
            return 1
        fi
    else
        print_error "kubectl is not installed"
        return 1
    fi
}

# Function to test Kind
test_kind() {
    print_status "Testing Kind..."
    if command_exists kind; then
        if kind version >/dev/null 2>&1; then
            print_success "Kind is working: $(kind version)"
            return 0
        else
            print_error "Kind is installed but not working properly"
            return 1
        fi
    else
        print_error "Kind is not installed"
        return 1
    fi
}

# Function to test siege
test_siege() {
    print_status "Testing siege..."
    if command_exists siege; then
        # Test if siege works by running it with a simple test
        if siege -c 1 -t 1s http://example.com >/dev/null 2>&1; then
            print_success "siege is working: $(siege --version 2>/dev/null || echo "siege installed")"
            return 0
        else
            print_error "siege is installed but not working properly"
            return 1
        fi
    else
        print_error "siege is not installed"
        return 1
    fi
}

# Function to test demo app build
test_demo_app() {
    print_status "Testing demo app build..."
    if [ -d "demo-app" ]; then
        cd demo-app
        if docker build -t test-demo-app . >/dev/null 2>&1; then
            print_success "Demo app builds successfully"
            docker rmi test-demo-app >/dev/null 2>&1
            cd ..
            return 0
        else
            print_error "Demo app build failed"
            cd ..
            return 1
        fi
    else
        print_error "demo-app directory not found"
        return 1
    fi
}

# Function to test Kubernetes manifests
test_manifests() {
    print_status "Testing Kubernetes manifests..."
    if [ -d "monolith-migration/base-manifest" ]; then
        cd monolith-migration/base-manifest
        if kubectl kustomize . >/dev/null 2>&1; then
            print_success "Kubernetes manifests are valid"
            cd ../..
            return 0
        else
            print_error "Kubernetes manifests are invalid"
            cd ../..
            return 1
        fi
    else
        print_error "monolith-migration/base-manifest directory not found"
        return 1
    fi
}

# Main execution
main() {
    echo "🧪 KubeCon 2025 Demo Setup Test"
    echo "================================"
    echo ""
    
    local all_tests_passed=true
    
    # Run all tests
    test_docker || all_tests_passed=false
    test_kubectl || all_tests_passed=false
    test_kind || all_tests_passed=false
    test_siege || all_tests_passed=false
    test_demo_app || all_tests_passed=false
    test_manifests || all_tests_passed=false
    
    echo ""
    if [ "$all_tests_passed" = true ]; then
        print_success "All tests passed! Your setup is ready for the demo."
        echo ""
        echo "Next steps:"
        echo "1. Follow the README.md instructions to run the demo"
        echo "2. Or use the quick start commands in the README"
    else
        print_error "Some tests failed. Please fix the issues and run this script again."
        exit 1
    fi
}

# Run main function
main "$@"
