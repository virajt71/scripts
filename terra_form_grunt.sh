#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Terraform and Terragrunt versions
TERRAFORM_VERSION="1.7.4"
TERRAGRUNT_VERSION="0.55.1"

echo -e "${GREEN}=== Terraform and Terragrunt Installation Script ===${NC}"
echo ""

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            OS_VERSION=$VERSION_ID
        elif [ -f /etc/redhat-release ]; then
            OS="rhel"
        else
            OS="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi
    
    print_info "Detected OS: $OS"
}

# Detect architecture
detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="arm"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    print_info "Detected architecture: $ARCH"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Terraform
install_terraform() {
    print_info "Installing Terraform version $TERRAFORM_VERSION..."
    
    if command_exists terraform; then
        CURRENT_VERSION=$(terraform version -json | grep -o '"version":"[^"]*' | cut -d'"' -f4 | head -n1)
        print_warn "Terraform is already installed (version: $CURRENT_VERSION)"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    case $OS in
        ubuntu|debian)
            # HashiCorp official repository method
            wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt-get update
            sudo apt-get install -y terraform
            ;;
            
        rhel|centos|fedora|rocky|almalinux)
            # HashiCorp official repository method
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
            sudo yum -y install terraform
            ;;
            
        sles|opensuse*|suse)
            # Manual installation for SUSE
            install_terraform_binary
            ;;
            
        arch|manjaro)
            sudo pacman -Sy --noconfirm terraform
            ;;
            
        macos)
            if command_exists brew; then
                brew tap hashicorp/tap
                brew install hashicorp/tap/terraform
            else
                print_warn "Homebrew not found. Installing Terraform manually..."
                install_terraform_binary
            fi
            ;;
            
        *)
            print_warn "OS not recognized. Installing Terraform manually..."
            install_terraform_binary
            ;;
    esac
    
    print_info "Terraform installation completed!"
    terraform version
}

# Install Terraform binary manually
install_terraform_binary() {
    print_info "Installing Terraform binary manually..."
    
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    if [[ "$OS" == "macos" ]]; then
        OS_NAME="darwin"
    else
        OS_NAME="linux"
    fi
    
    DOWNLOAD_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${OS_NAME}_${ARCH}.zip"
    
    print_info "Downloading from: $DOWNLOAD_URL"
    wget -q "$DOWNLOAD_URL" -O terraform.zip
    
    unzip -q terraform.zip
    sudo mv terraform /usr/local/bin/
    sudo chmod +x /usr/local/bin/terraform
    
    cd - > /dev/null
    rm -rf "$TMP_DIR"
}

# Install Terragrunt
install_terragrunt() {
    print_info "Installing Terragrunt version $TERRAGRUNT_VERSION..."
    
    if command_exists terragrunt; then
        CURRENT_VERSION=$(terragrunt --version | head -n1 | awk '{print $3}' | sed 's/v//')
        print_warn "Terragrunt is already installed (version: $CURRENT_VERSION)"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    if [[ "$OS" == "macos" ]]; then
        OS_NAME="darwin"
    else
        OS_NAME="linux"
    fi
    
    DOWNLOAD_URL="https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_${OS_NAME}_${ARCH}"
    
    print_info "Downloading Terragrunt from: $DOWNLOAD_URL"
    sudo wget -q "$DOWNLOAD_URL" -O /usr/local/bin/terragrunt
    sudo chmod +x /usr/local/bin/terragrunt
    
    print_info "Terragrunt installation completed!"
    terragrunt --version
}

# Main installation process
main() {
    print_info "Starting installation process..."
    echo ""
    
    # Check for required tools
    if ! command_exists wget; then
        print_error "wget is required but not installed. Please install wget first."
        exit 1
    fi
    
    if ! command_exists unzip; then
        print_warn "unzip is not installed. Installing..."
        case $OS in
            ubuntu|debian)
                sudo apt-get update && sudo apt-get install -y unzip
                ;;
            rhel|centos|fedora|rocky|almalinux)
                sudo yum install -y unzip
                ;;
            arch|manjaro)
                sudo pacman -Sy --noconfirm unzip
                ;;
            sles|opensuse*|suse)
                sudo zypper install -y unzip
                ;;
            macos)
                # unzip is usually pre-installed on macOS
                ;;
        esac
    fi
    
    detect_os
    detect_arch
    echo ""
    
    install_terraform
    echo ""
    
    install_terragrunt
    echo ""
    
    print_info "${GREEN}✓${NC} Installation completed successfully!"
    echo ""
    echo "Installed versions:"
    terraform version
    terragrunt --version
}

# Run main function
main
