#!/bin/bash

# Docker Installation Script with OS Detection
# Supports: Ubuntu, Debian, RHEL/CentOS/Fedora, SUSE, Arch Linux, and macOS

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        print_message "Detected macOS"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu)
                OS="ubuntu"
                print_message "Detected Ubuntu $VERSION_ID"
                ;;
            debian)
                OS="debian"
                print_message "Detected Debian $VERSION_ID"
                ;;
            rhel|centos|fedora|rocky|almalinux)
                OS="rhel"
                print_message "Detected RHEL-based system: $ID $VERSION_ID"
                ;;
            opensuse*|sles)
                OS="suse"
                print_message "Detected SUSE-based system: $ID $VERSION_ID"
                ;;
            arch|manjaro)
                OS="arch"
                print_message "Detected Arch-based system: $ID"
                ;;
            *)
                print_error "Unsupported Linux distribution: $ID"
                exit 1
                ;;
        esac
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
}

# Function to check if Docker is already installed
check_docker() {
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        print_warning "Docker is already installed: $DOCKER_VERSION"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message "Installation cancelled"
            exit 0
        fi
    fi
}

# Install Docker on Ubuntu/Debian
install_docker_ubuntu_debian() {
    print_message "Installing Docker on Ubuntu/Debian..."
    
    # Update package index
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Install Docker on RHEL/CentOS/Fedora
install_docker_rhel() {
    print_message "Installing Docker on RHEL-based system..."
    
    # Remove old versions if any
    sudo yum remove -y docker docker-client docker-client-latest docker-common \
        docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc 2>/dev/null || true
    
    # Install prerequisites
    sudo yum install -y yum-utils
    
    # Add Docker repository
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker Engine
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Install Docker on SUSE
install_docker_suse() {
    print_message "Installing Docker on SUSE..."
    
    # Remove old versions
    sudo zypper remove -y docker docker-engine runc 2>/dev/null || true
    
    # Add Docker repository
    sudo zypper addrepo https://download.docker.com/linux/sles/docker-ce.repo
    
    # Install Docker Engine
    sudo zypper refresh
    sudo zypper install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Install Docker on Arch Linux
install_docker_arch() {
    print_message "Installing Docker on Arch Linux..."
    
    # Update package database
    sudo pacman -Sy
    
    # Install Docker
    sudo pacman -S --noconfirm docker docker-compose
    
    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Install Docker on macOS
install_docker_macos() {
    print_message "Installing Docker Desktop on macOS..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        print_error "Homebrew is not installed. Please install Homebrew first:"
        print_error "Visit https://brew.sh/"
        exit 1
    fi
    
    # Install Docker Desktop using Homebrew Cask
    print_message "Installing Docker Desktop via Homebrew..."
    brew install --cask docker
    
    print_warning "Please start Docker Desktop from your Applications folder"
    print_warning "Docker Desktop needs to be running for Docker commands to work"
}

# Install Docker Compose (standalone if not included with Docker)
install_docker_compose() {
    print_message "Checking Docker Compose installation..."
    
    # Check if docker compose plugin is available
    if docker compose version &> /dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version)
        print_message "Docker Compose plugin already installed: $COMPOSE_VERSION"
        return 0
    fi
    
    # Check if standalone docker-compose is available
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version)
        print_message "Docker Compose (standalone) already installed: $COMPOSE_VERSION"
        return 0
    fi
    
    # Install standalone Docker Compose if not available
    print_message "Installing Docker Compose standalone..."
    
    # Get latest version
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    
    if [ -z "$COMPOSE_VERSION" ]; then
        print_warning "Could not fetch latest version, using v2.24.5"
        COMPOSE_VERSION="v2.24.5"
    fi
    
    print_message "Installing Docker Compose $COMPOSE_VERSION..."
    
    # Download and install
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symbolic link
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    
    # Verify installation
    if command -v docker-compose &> /dev/null; then
        print_message "Docker Compose installed successfully: $(docker-compose --version)"
    else
        print_error "Docker Compose installation failed"
        return 1
    fi
}

# Add current user to docker group and set permissions (Linux only)
configure_docker_permissions() {
    if [[ "$OS" != "macos" ]]; then
        print_message "Configuring Docker permissions and services..."
        
        # Create docker group if it doesn't exist
        if ! getent group docker > /dev/null 2>&1; then
            print_message "Creating docker group..."
            sudo groupadd docker
        else
            print_message "Docker group already exists"
        fi
        
        # Add current user to docker group
        print_message "Adding user '$USER' to docker group..."
        sudo usermod -aG docker $USER
        
        # Set permissions on docker socket
        if [ -e /var/run/docker.sock ]; then
            print_message "Setting permissions on /var/run/docker.sock..."
            sudo chmod 777 /var/run/docker.sock
            print_message "Docker socket permissions updated"
        else
            print_warning "Docker socket not found yet, will be created on Docker start"
        fi
        
        # Fix docker directory permissions if it exists
        if [ -d "$HOME/.docker" ]; then
            print_message "Setting ownership and permissions on $HOME/.docker..."
            sudo chown "$USER":"$USER" "$HOME/.docker" -R
            sudo chmod g+rwx "$HOME/.docker" -R
            print_message "Docker directory permissions updated"
        else
            print_message "Docker config directory doesn't exist yet (will be created on first use)"
        fi
        
        # Enable Docker services
        print_message "Enabling Docker services to start on boot..."
        sudo systemctl enable docker.service
        sudo systemctl enable containerd.service
        print_message "Docker services enabled"
        
        # Apply group changes for current session
        print_message "Applying group changes for current session..."
        newgrp docker << END
echo "Group changes applied"
END
        
        print_warning "Note: You may still need to log out and log back in for full group changes"
        print_message "Docker is now configured to start automatically on boot"
    fi
}

# Verify installation
verify_installation() {
    print_message "Verifying Docker installation..."
    
    if [[ "$OS" == "macos" ]]; then
        print_warning "Please start Docker Desktop and then run: docker --version"
        print_warning "Docker Compose will be available through Docker Desktop"
    else
        # Try to run docker version
        if sudo docker --version &> /dev/null; then
            sudo docker --version
            print_message "Docker installed successfully!"
            
            # Check Docker Compose
            if docker compose version &> /dev/null 2>&1; then
                docker compose version
                print_message "Docker Compose (plugin) is available"
            elif command -v docker-compose &> /dev/null; then
                docker-compose --version
                print_message "Docker Compose (standalone) is available"
            else
                print_warning "Docker Compose may not be properly installed"
            fi

        else
            print_error "Docker installation verification failed"
            exit 1
        fi
    fi
}

# Main installation flow
main() {
    print_message "Starting Docker installation..."
    echo
    
    # Detect OS
    detect_os
    
    # Check if Docker is already installed
    check_docker
    
    # Install based on OS
    case "$OS" in
        ubuntu|debian)
            install_docker_ubuntu_debian
            ;;
        rhel)
            install_docker_rhel
            ;;
        suse)
            install_docker_suse
            ;;
        arch)
            install_docker_arch
            ;;
        macos)
            install_docker_macos
            ;;
        *)
            print_error "Unsupported operating system"
            exit 1
            ;;
    esac
    
    # Install Docker Compose
    echo
    install_docker_compose
    
    # Configure Docker permissions
    configure_docker_permissions
    
    # Verify installation
    echo
    verify_installation
    
    echo
    print_message "Installation complete!"
    print_message "Docker and Docker Compose are now ready to use!"
    
    if [[ "$OS" != "macos" ]]; then
        echo
        print_message "Docker permissions and services configured:"
        print_message "  ✓ Docker group created/verified"
        print_message "  ✓ User '$USER' added to docker group"
        print_message "  ✓ Docker socket permissions set (chmod 777)"
        print_message "  ✓ Docker config directory ownership updated"
        print_message "  ✓ Docker services enabled (docker.service & containerd.service)"
        print_message "  ✓ Docker Compose installed and verified"
        print_message "  ✓ Group changes applied with newgrp"
        echo
        print_warning "If you open a new terminal, you may need to run 'newgrp docker' again"
        print_warning "Or log out and log back in for permanent group membership"
        echo
        print_message "Docker will now start automatically on system boot"
        echo
        print_message "Quick start commands:"
        print_message "  docker --version"
        print_message "  docker compose version"
    fi
}

# Run main function
main
