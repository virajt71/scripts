#!/bin/bash

# Jenkins Installation Script with Java 21
# Supports: Ubuntu/Debian, RHEL/CentOS/Fedora, Arch-based distros, macOS

set -e

# Colors for output
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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ "$(uname)" = "Darwin" ]; then
        OS="macos"
        OS_VERSION=$(sw_vers -productVersion)
    else
        print_error "Cannot detect OS"
        exit 1
    fi
    
    print_message "Detected OS: $OS $OS_VERSION"
}

# Install Java 21 based on OS
install_java21() {
    print_message "Installing Java 21..."
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y wget curl apt-transport-https gnupg
            
            # Install OpenJDK 21
            apt-get install -y openjdk-21-jdk
            ;;
            
        rhel|centos|fedora|rocky|almalinux)
            # Determine package manager
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi
            
            # Install Java 21 and fontconfig (Jenkins dependency)
            $PKG_MANAGER install -y fontconfig java-21-openjdk java-21-openjdk-devel
            ;;
            
        arch|manjaro|garuda|endeavouros|arcolinux|artix)
            pacman -Sy --noconfirm jdk21-openjdk
            archlinux-java set java-21-openjdk
            ;;
            
        macos)
            if ! command -v brew &> /dev/null; then
                print_error "Homebrew is not installed. Please install it first from https://brew.sh"
                exit 1
            fi
            brew install openjdk@21
            
            # Link Java for macOS
            sudo ln -sfn $(brew --prefix)/opt/openjdk@21/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-21.jdk
            ;;
            
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    # Verify Java installation
    java -version
    print_message "Java 21 installed successfully"
}

# Install Jenkins based on OS
install_jenkins() {
    print_message "Installing Jenkins..."
    
    case $OS in
        ubuntu|debian)
            # Remove old Jenkins repository if exists
            rm -f /etc/apt/sources.list.d/jenkins.list
            
            # Add Jenkins repository with 2026 key
            mkdir -p /etc/apt/keyrings
            wget -O /etc/apt/keyrings/jenkins-keyring.asc \
                https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
            
            echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
                tee /etc/apt/sources.list.d/jenkins.list > /dev/null
            
            apt-get update
            apt-get install -y jenkins
            
            # Start and enable Jenkins
            systemctl start jenkins
            systemctl enable jenkins
            ;;
            
        rhel|centos|fedora|rocky|almalinux)
            # Add Jenkins repository
            wget -O /etc/yum.repos.d/jenkins.repo \
                https://pkg.jenkins.io/rpm-stable/jenkins.repo
            rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
            
            # Determine package manager and upgrade
            if command -v dnf &> /dev/null; then
                dnf upgrade -y
                dnf install -y jenkins
            else
                yum upgrade -y
                yum install -y jenkins
            fi
            
            # Reload systemd and start Jenkins
            systemctl daemon-reload
            systemctl start jenkins
            systemctl enable jenkins
            ;;
            
        arch|manjaro|garuda|endeavouros|arcolinux|artix)
            # Install Jenkins from AUR (using helper or manual)
            print_warning "For Arch-based systems, Jenkins needs to be installed from AUR"
            
            # Check if yay is available
            if command -v yay &> /dev/null; then
                sudo -u $SUDO_USER yay -S --noconfirm jenkins
            elif command -v paru &> /dev/null; then
                sudo -u $SUDO_USER paru -S --noconfirm jenkins
            else
                print_message "Installing Jenkins manually..."
                
                # Create temporary directory
                TEMP_DIR=$(mktemp -d)
                cd $TEMP_DIR
                
                # Download and install Jenkins
                wget https://pkg.jenkins.io/redhat-stable/jenkins-2.426.1-1.1.noarch.rpm
                pacman -U --noconfirm jenkins-2.426.1-1.1.noarch.rpm
                
                cd -
                rm -rf $TEMP_DIR
            fi
            
            # Start and enable Jenkins
            systemctl start jenkins
            systemctl enable jenkins
            ;;
            
        macos)
            brew install jenkins-lts
            
            # Start Jenkins
            brew services start jenkins-lts
            ;;
            
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    print_message "Jenkins installed successfully"
}

# Configure firewall if needed
configure_firewall() {
    print_message "Checking firewall status..."
    
    case $OS in
        ubuntu|debian)
            if command -v ufw &> /dev/null; then
                # Check if UFW is active
                if ufw status | grep -q "Status: active"; then
                    print_message "UFW firewall is active, configuring port 8080..."
                    ufw allow 8080/tcp
                    print_message "Firewall configured to allow port 8080"
                else
                    print_message "UFW firewall is not active, skipping firewall configuration"
                fi
            else
                print_message "UFW not found, skipping firewall configuration"
            fi
            ;;
            
        rhel|centos|fedora|rocky|almalinux)
            if command -v firewall-cmd &> /dev/null; then
                # Check if firewalld is running
                if systemctl is-active --quiet firewalld; then
                    print_message "Firewalld is active, configuring port 8080..."
                    firewall-cmd --permanent --add-port=8080/tcp
                    firewall-cmd --reload
                    print_message "Firewall configured to allow port 8080"
                else
                    print_message "Firewalld is not active, skipping firewall configuration"
                fi
            else
                print_message "Firewalld not found, skipping firewall configuration"
            fi
            ;;
            
        *)
            print_message "No firewall configuration needed for this OS"
            ;;
    esac
}

# Get initial admin password
get_admin_password() {
    print_message "Waiting for Jenkins to initialize..."
    sleep 10
    
    local password_file="/var/lib/jenkins/secrets/initialAdminPassword"
    
    if [ "$OS" = "macos" ]; then
        password_file="/usr/local/var/jenkins/home/secrets/initialAdminPassword"
    fi
    
    if [ -f "$password_file" ]; then
        print_message "=========================================="
        print_message "Jenkins Initial Admin Password:"
        cat "$password_file"
        print_message "=========================================="
    else
        print_warning "Initial admin password file not found yet. It may take a few moments for Jenkins to start."
        print_message "You can retrieve it later from: $password_file"
    fi
}

# Main installation flow
main() {
    print_message "Starting Jenkins installation with Java 21..."
    
    check_root
    detect_os
    install_java21
    install_jenkins
    configure_firewall
    # get_admin_password
    
    print_message "=========================================="
    print_message "Installation completed successfully!"
    print_message "=========================================="
    print_message "Jenkins is running on: http://localhost:8080"
    print_message ""
    print_message "Next steps:"
    print_message "1. Open http://localhost:8080 in your browser"
    print_message "2. Use the initial admin password shown above"
    print_message "3. Complete the setup wizard"
    print_message "=========================================="
}

# Run main function
main
