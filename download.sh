#!/bin/bash

source ./include.sh

# Download ISO images for the main Linux distributions
# and save them to the specified directory.
# Usage: ./download.sh

# Define the directory to save the downloaded images
DOWNLOAD_DIR="$HOME/Downloads/iso_images"
mkdir -p "$DOWNLOAD_DIR"

# Select the Linux distribution to download
# Use methods from ./include.sh to select the distro.
selected_distro=$(select_distro ${DISTROS[@]})

# TODO: allow selecting multiple distros
selected_distros=(${select_distros ${DISTROS[@]})

# echo "Selected distro: $selected_distro"
#exit 1

# Loop through the DISTROS array and download each ISO
# for distro in "${!DISTROS[@]}"; do
#     download_iso "${DISTROS[$distro]}"
# done
download_file "${DISTROS[$selected_distro]}"

# Check if all downloads were successful
if [ $? -eq 0 ]; then
    print $GREEN "Download completed!" "All ISO images downloaded successfully."
else
    print $RED "Error:" "Some downloads failed. Please check the logs."
fi
# End of script