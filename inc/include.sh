# Include file with functions to be used by the scripts in the repository
# This file is sourced by the scripts in the repository
# This file is not meant to be executed directly

DIALOG_HEIGHT=20
DIALOG_WIDTH=60

# Calculate currently available height and width of the terminal
# Use tput to get the height and width of the terminal.
# The height and width are stored in the variables $DIALOG_HEIGHT and $DIALOG_WIDTH.
SCREEN_HEIGHT=$(tput lines)
SCREEN_WIDTH=$(tput cols)
# Check if the terminal is too small
if [ $SCREEN_HEIGHT -lt 20 ] || [ $SCREEN_WIDTH -lt 60 ]; then
    print_red "Terminal is too small. Please resize the terminal and try again. Exiting..."
    exit 1
fi

# Calculate the height and width of the dialog, to be the percentage of the terminal size
DIALOG_HEIGHT=$((SCREEN_HEIGHT * 70 / 100))
DIALOG_WIDTH=$((SCREEN_WIDTH * 70 / 100))

# List of Linux distributions and their download URLs
declare -A DISTROS=(
  # Main Linux Distributions
  [Ubuntu_amd64]="https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso"
  [Ubuntu_i386]="https://releases.ubuntu.com/18.04/ubuntu-18.04.6-desktop-i386.iso"
  [Ubuntu_arm64]="https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04-live-server-arm64.iso"
  
  [Debian_amd64]="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso"
  [Debian_i386]="https://cdimage.debian.org/debian-cd/current/i386/iso-cd/debian-12.5.0-i386-netinst.iso"
  [Debian_arm64]="https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/debian-12.5.0-arm64-netinst.iso"
  
  [Fedora_amd64]="https://download.fedoraproject.org/pub/fedora/linux/releases/42/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-42-1.6.iso"
  [Fedora_arm64]="https://download.fedoraproject.org/pub/fedora/linux/releases/42/Workstation/aarch64/iso/Fedora-Workstation-Live-aarch64-42-1.6.iso"
  
  [ArchLinux_amd64]="https://mirror.rackspace.com/archlinux/iso/2025.05.01/archlinux-2025.05.01-x86_64.iso"
  [ArchLinux_arm64]="https://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
  
  [openSUSE_amd64]="https://download.opensuse.org/distribution/leap/15.6/iso/openSUSE-Leap-15.6-DVD-x86_64.iso"
  [openSUSE_arm64]="https://download.opensuse.org/ports/aarch64/distribution/leap/15.6/iso/openSUSE-Leap-15.6-DVD-aarch64.iso"
  
  [LinuxMint_amd64]="https://mirrors.edge.kernel.org/linuxmint/stable/22.1/linuxmint-22.1-cinnamon-64bit.iso"
  [LinuxMint_i386]="https://mirrors.edge.kernel.org/linuxmint/stable/19.3/linuxmint-19.3-cinnamon-32bit.iso"
  
  [Manjaro_amd64]="https://download.manjaro.org/gnome/23.1.0/manjaro-gnome-23.1.0-231017-linux65.iso"
  [Manjaro_arm64]="https://github.com/manjaro-arm/raspberrypi/releases/download/23.02/Manjaro-ARM-kde-plasma-rpi4-23.02.img.xz"
  
  [elementaryOS_amd64]="https://github.com/elementary/iso/releases/download/7.1/elementaryos-7.1-stable.20231015.iso"
  
  [ZorinOS_amd64]="https://zorin.com/os/download/17/core/"
  
  [MXLinux_amd64]="https://sourceforge.net/projects/mx-linux/files/Final/MX-23.1/MX-23.1_x64.iso/download"
  [MXLinux_i386]="https://sourceforge.net/projects/mx-linux/files/Final/MX-23.1/MX-23.1_386.iso/download"
  
  [antiX_amd64]="https://sourceforge.net/projects/antix-linux/files/Final/antiX-23/antiX-23_x64-full.iso/download"
  [antiX_i386]="https://sourceforge.net/projects/antix-linux/files/Final/antiX-23/antiX-23_386-full.iso/download"
  
  [Slackware_amd64]="https://mirrors.slackware.com/slackware/slackware-15.0-iso/slackware-15.0-install-dvd.iso"
  [Slackware_arm64]="https://ftp.arm.slackware.com/slackwarearm-15.0/iso/slackwarearm-15.0-aarch64.iso"
  
  [Gentoo_amd64]="https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/current-install-amd64-minimal/install-amd64-minimal-20250512T214502Z.iso"
  [Gentoo_arm64]="https://bouncer.gentoo.org/fetch/root/all/releases/arm64/autobuilds/current-install-arm64-minimal/install-arm64-minimal-20250512T214502Z.iso"
  
  [VoidLinux_amd64]="https://repo-default.voidlinux.org/live/current/void-live-x86_64-20250512.iso"
  [VoidLinux_i386]="https://repo-default.voidlinux.org/live/current/void-live-i686-20250512.iso"
  [VoidLinux_arm64]="https://repo-default.voidlinux.org/live/current/void-aarch64-ROOTFS-20250512.tar.xz"
  
  # Lightweight & Legacy Hardware Support
  [PuppyLinux_amd64]="https://distro.ibiblio.org/puppylinux/puppy-slacko-7.0/puppy-slacko64-7.0.iso"
  [PuppyLinux_i386]="https://distro.ibiblio.org/puppylinux/puppy-slacko-7.0/puppy-slacko-7.0.iso"
  
  [TinyCore_amd64]="http://tinycorelinux.net/15.x/x86_64/release/TinyCorePure64-15.0.iso"
  [TinyCore_i386]="http://tinycorelinux.net/15.x/x86/release/TinyCore-15.0.iso"
  
  [BodhiLinux_amd64]="https://sourceforge.net/projects/bodhilinux/files/6.0.0/bodhi-6.0.0-64.iso/download"
  [BodhiLinux_i386]="https://sourceforge.net/projects/bodhilinux/files/5.1.0/bodhi-5.1.0-32.iso/download"
  
  [Slax_amd64]="https://ftp.slax.org/Slax-15.0.1/slax-64bit-15.0.1.iso"
  [Slax_i386]="https://ftp.slax.org/Slax-15.0.1/slax-32bit-15.0.1.iso"
  
  [Q4OS_amd64]="https://sourceforge.net/projects/q4os/files/stable/q4os-5.2-x64.r1.iso/download"
  [Q4OS_i386]="https://sourceforge.net/projects/q4os/files/stable/q4os-5.2-i386.r1.iso/download"
  
  [PeppermintOS_amd64]="https://peppermintos.com/iso/PeppermintOS-amd64.iso"
  
  # Rescue & Cloning Distributions
  [SystemRescue_amd64]="https://www.system-rescue.org/download/systemrescue-10.01-amd64.iso"
  [SystemRescue_i386]="https://www.system-rescue.org/download/systemrescue-10.01-i686.iso"
  
  [Rescatux_amd64]="https://sourceforge.net/projects/rescatux/files/rescatux-0.73/rescatux-0.73.iso/download"
  
  [Clonezilla_amd64]="https://downloads.sourceforge.net/project/clonezilla/clonezilla_live_stable/3.0.5-22/clonezilla-live-3.0.5-22-amd64.iso"
  [Clonezilla_i386]="https://downloads.sourceforge.net/project/clonezilla/clonezilla_live_stable/3.0.5-22/clonezilla-live-3.0.5-22-i686.iso"
  
  [RedoRescue_amd64]="https://github.com/redorescue/redorescue/releases/download/4.0.0/redo-rescue-4.0.0.iso"
  
  [GPartedLive_amd64]="https://downloads.sourceforge.net/project/gparted/gparted-live-stable/1.5.0-1/gparted-live-1.5.0-1-amd64.iso"
  [GPartedLive_i386]="https://downloads.sourceforge.net/project/gparted/gparted-live-stable/1.5.0-1/gparted-live-1.5.0-1-i686.iso"
  
  [GRML_amd64]="https://download.grml.org/grml64-full_2025.05.iso"
  [GRML_i386]="https://download.grml.org/grml32-full_2025.05.iso"
  
  # Penetration Testing & Security Distributions
  [KaliLinux_amd64]="https://cdimage.kali.org/kali-2025.1/kali-linux-2025.1-installer-amd64.iso"
  [KaliLinux_i386]="https://cdimage.kali.org/kali-2025.1/kali-linux-2025.1-installer-i386.iso"
  [KaliLinux_arm64]="https://cdimage.kali.org/kali-2025.1/kali-linux-2025.1-installer-arm64.iso"
  
  [ParrotOS_amd64]="https://download.parrot.sh/parrot/iso/5.2/Parrot-security-5.2_amd64.iso"
  [ParrotOS_arm64]="https://download.parrot.sh/parrot/iso/5.2/Parrot-security-5.2_arm64.iso"
  
  [BackBox_amd64]="https://mirror.backbox.org/backbox/backbox-8.0-amd64.iso"
  
  [BlackArch_amd64]="https://blackarch.org/iso/blackarch-linux-live-202
::contentReference[oaicite:2]{index=2}"
)

# Define colors for printing messages
# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
WHITE='\033[0;37m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Define functions for printing messages in different colors
print() {
    local color="$1"
    local message="$2"
    # Allow second text parameter - if set, then start with gray text
    local message2="$3"
 
    # If message2 is set, then print message in gray, and message2 in color
    if [ -n "$message2" ]; then
        echo -e "${color}${message}${NC} ${WHITE}${message2}${NC}"
        echo "...."
    else
        echo -e "${color}${message}${NC}"
        echo "...."
    fi
}

install_dependencies(){
    # Install: 
    # -dialog
    # -curl
    # -wget
    # -lsblk
    # local dependencies="$@"
    local dependencies="dialog curl wget util-linux"
    
    # Check if the package manager is available
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y $dependencies
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y $dependencies
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm $dependencies
    else
        print $RED "No supported package manager found." "Please install: $dependencies manually."
        exit 1
    fi
}

check_if_dialog_installed() {
    if ! command -v dialog &> /dev/null; then
        print $RED "Dialog is not installed" "Please install dialog and try again. Exiting..."
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a directory exists
directory_exists() {
    if [ -d "$1" ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a file exists
file_exists() {
    if [ -f "$1" ]; then
        return 0
    else
        return 1
    fi
}

# Function to create a directory if it doesn't exist
create_directory() {
    if ! directory_exists "$1"; then
        mkdir -p "$1"
        echo "Directory $1 created."
        return 0
    else
        echo "Directory $1 already exists."
        return 1
    fi
}

# Function to select multiple distros
select_multiple_distros() {
    local selected_distros
    local options=()
    
    # Using a parameter for the function.
    # for d in "${!distros[@]}"; do
    #     options+=("$d" "${distros[$d]}")
    # done

    # Without parameters for the function.
    for d in "${!DISTROS[@]}"; do
        options+=("$d" "${DISTROS[$d]}")
    done

    selected_distros=$(dialog --stdout --title "Select Linux Distro" --checklist "Choose Linux distributions to download:" $DIALOG_HEIGHT $DIALOG_WIDTH 0 "${options[@]}")

    if [ $? -ne 0 ]; then
        print $RED "No distro selected. Exiting..."
        exit 1
    fi

    echo "$selected_distros"
    return 0
}

# Select the Distro to download. Use Dialog to select the distro.
select_distro() {
    # List passed to the function.
    # local distros=("$@")
    # Associative Array parameter passed to the function.
    # declare -n distros="$1"

    local selected_distro

    local options=()
    
    # Using a parameter for the function.
    # for d in "${!distros[@]}"; do
    #     options+=("$d" "${distros[$d]}")
    # done


    # Without parameters for the function.
    for d in "${!DISTROS[@]}"; do
        options+=("$d" "${DISTROS[$d]}")
    done

    selected_distro=$(dialog --stdout --title "Select Linux Distro" --menu "Choose a Linux distribution to download:" $DIALOG_HEIGHT $DIALOG_WIDTH 0 "${options[@]}")

    if [ $? -ne 0 ]; then
        print $RED "No distro selected. Exiting..."
        exit 1
    fi

    echo "$selected_distro"
    return 0
}

# Function to download a file
download_file() {
    local url="$1"
    local output="$2"

    if [ -z "$output" ]; then
        output=$(basename "$url")
        # If $output doesnot have the extension (any extension), we will try to get whatever would be in the format: http(s)://...../file.ext/anything -> file.ext in this case

        if [[ "$output" != *.* ]]; then
            output=$(echo "$url" | sed -E 's|.*/([^/]+\.[^/]+)(/.*)?$|\1|')
        fi
    fi

    print $YELLOW "Downloading $url -> $output ..."
    
    if command_exists curl; then
        print $YELLOW "curl --max-time 3600 -L -o \"$output\" \"$url\""
        curl --max-time 3600 -L -o "$output" "$url"  # Set timeout to 3600 seconds (1 hour)
    elif command_exists wget; then
        print $YELLOW "wget --timeout=3600 -O \"$output\" \"$url\""
        wget --timeout=3600 -O "$output" "$url"  # Set timeout to 3600 seconds (1 hour)
    else
        print $RED "Error: Neither curl nor wget is installed." "Please install one of them to download files."
        return 1
    fi

    if [ $? -ne 0 ]; then
        print $RED "Error: Failed to download $url." "Please check the URL or your internet connection."
        return 1
    else
        print $GREEN "Download completed: $output"
        return 0
    fi
}

# Function to download an ISO image
download_iso() {
    local distro_name="$1"
    
    # Get the URL from the DISTROS array
    local url="${DISTROS[$distro_name]}"
    if [ -z "$url" ]; then
        print $RED "Error: No URL found for $distro_name." "Please check the DISTROS array."
        return 1
    fi
    # Get the output file name from the URL
    local output=$(basename "$url")
    # If $output doesnot have the extension (any extension), we will try to get whatever would be in the format: http(s)://...../file.ext/anything -> file.ext in this case

    if [[ "$output" != *.* ]]; then
        output=$(echo "$url" | sed -E 's|.*/([^/]+\.[^/]+)(/.*)?$|\1|')
    fi
    # Check if the file already exists
    if file_exists "$output"; then
        print $YELLOW "File $output already exists. Skipping download."
    fi

    # Download thefile
    download_file "$url" "$output"
    if [ $? -ne 0 ]; then
        print $RED "Error: Failed to download $distro_name." "Please check the URL or your internet connection."
        return 1
    fi
    print $GREEN "Download completed: $output"
    # Check if the file is a valid ISO image
    if is_valid_iso "$output"; then
        print $GREEN "$output is a valid ISO image."
        return 0
    else
        print $RED "$output is not a valid ISO image." "Please check the file."
        return 1
    fi
}

# Function to check if a file is a valid ISO image
is_valid_iso() {
    local file="$1"
    if file "$file" | grep -q "ISO 9660"; then
        return 0
    else
        return 1
    fi
}

# Function to check if a file is a valid checksum file
is_valid_checksum() {
    local file="$1"
    if file "$file" | grep -q "ASCII text"; then
        return 0
    else
        return 1
    fi
}

# Function to verify the checksum of a downloaded ISO image
verify_checksum() {
    local iso_file="$1"
    local checksum_file="$2"
    local checksum_type="${3:-sha256sum}"

    if ! is_valid_iso "$iso_file"; then
        print $RED "Error: $iso_file is not a valid ISO image." "Please check the file."
        return 1
    fi

    if ! is_valid_checksum "$checksum_file"; then
        print $RED "Error: $checksum_file is not a valid checksum file." "Please check the file."
        return 1
    fi

    if command_exists "$checksum_type"; then
        local checksum_output
        checksum_output=$("$checksum_type" -c "$checksum_file" 2>&1)
        if echo "$checksum_output" | grep -q "OK"; then
            print $GREEN "Checksum verification successful for $iso_file."
            return 0
        else
            print $RED "Checksum verification failed for $iso_file." "Please check the file."
            return 1
        fi
    else
        print $RED "Error: $checksum_type is not installed." "Please install it to verify checksums."
        return 1
    fi
}
