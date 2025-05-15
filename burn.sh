#!/bin/bash

source ./include.sh

DIALOG_DIRECTORY=$HOME/Downloads

# Check if dialog is installed
check_if_dialog_installed

# Select ISO using dialog
# Use dialog cli tool to select the ISO file from the file system.
# The selected file is stored in the variable $ISO_FILE.
# Start with Downloads directory.
# Make sure to pass the return value to ISO_FILE.
# Filter by .iso files only.
# ISO_FILE=$(dialog --stdout --title "Select ISO file (TAB = switch, SPACE = select)" --fselect "$DIALOG_DIRECTORY/" ${DIALOG_HEIGHT} ${DIALOG_WIDTH})
ISO_FILE=$(find "$DIALOG_DIRECTORY" -type f -name "*.iso" | dialog --stdout --title "Select ISO file (TAB = switch, SPACE = select)" --menu "Select an ISO file:" ${DIALOG_HEIGHT} ${DIALOG_WIDTH} 0 $(awk '{print $0, NR}' | tr '\n' ' '))

# Check if the user has selected a file or canceled the dialog
# If the user has canceled the dialog, exit the script.
if [ $? -ne 0 ]; then
    # print_red "No file selected. Exiting..."
    dialog --backtitle "Error" --title "No File Selected" --msgbox "No ISO files selected. Please make sure you have selected the correct ISO file. Exiting..." $DIALOG_HEIGHT $DIALOG_WIDTH
    clear
    exit 1
fi

# Check if the selected file is an ISO file
# If the selected file is not an ISO file, exit the script.
if [ ${ISO_FILE: -4} != ".iso" ]; then
    # print_red "The selected file is not an ISO file. Exiting..."
    dialog --backtitle "Error" --title "No File Selected" --msgbox "No ISO files selected. Please make sure you have selected the correct ISO file. Exiting..." $DIALOG_HEIGHT $DIALOG_WIDTH
    exit 1
fi

# List all the block devices
# Use lsblk to list all the block devices on the system.
# The block devices are stored in the variable $BLOCK_DEVICES.
# SOURCE_DEVICES="disk|usb|sd"
SOURCE_DEVICES="usb"
BLOCK_DEVICES=$(lsblk -d -o NAME,SIZE,TRAN | grep -E ${SOURCE_DEVICES} | awk '{print $1,$2,$3}')
# echo "block devices: $BLOCK_DEVICES"
# exit 2

# Check if there are any block devices on the system
# If there are no block devices on the system, exit the script.
if [ -z "$BLOCK_DEVICES" ]; then
    dialog --backtitle "Error" --title "No Block Devices Found" --msgbox "No block devices found on the system. Exiting..." $DIALOG_HEIGHT $DIALOG_WIDTH
    exit 1
fi

# Select block device using dialog
# Use dialog cli tool to select the block device from the list of block devices.
# The selected block device is stored in the variable $BLOCK_DEVICE.
BLOCK_DEVICE=$(echo "$BLOCK_DEVICES" | awk '{print $1, $1}' | tr '\n' ' ' | xargs dialog --stdout --title "Select block device \
Press SPACE to select the device" --menu "Select the block device to burn the ISO file to:" $DIALOG_HEIGHT $DIALOG_WIDTH 17)


# Check if the user has selected a block device or canceled the dialog
# If the user has canceled the dialog, exit the script.
if [ $? -ne 0 ]; then
    # print_red "No block device selected. Exiting..."
    dialog --backtitle "Error" --title "No Block Devices Selected" --msgbox "No block devices were selected. Please select the destination block device you would like to write ISO file to. Exiting..." $DIALOG_HEIGHT $DIALOG_WIDTH
    exit 1
fi

## Check if the selected block device is a disk
## If the selected block device is not a disk, exit the script.
#if [ $(lsblk -d -o NAME,TRAN | grep $BLOCK_DEVICE | awk '{print $2}') != "disk" ]; then
#    print_red "The selected block device is not a disk. Exiting..."
#    exit 1
#fi

## Check if the selected block device is a USB disk
## If the selected block device is not a USB disk, exit the script.
#if [ $(lsblk -d -o NAME,TRAN | grep $BLOCK_DEVICE | awk '{print $2}') != "usb" ]; then
#    print_red "The selected block device is not a USB disk. Exiting..."
#    exit 1
#fi

## Check if the selected block device is a SD disk
## If the selected block device is not a SD disk, exit the script.
#if [ $(lsblk -d -o NAME,TRAN | grep $BLOCK_DEVICE | awk '{print $2}') != "sd" ]; then
#    print_red "The selected block device is not a SD disk. Exiting..."
#    exit 1
#fi

# Check if the selected block device is mounted
# If the selected block device is mounted, exit the script.
if [ $(lsblk -o MOUNTPOINT | grep $BLOCK_DEVICE) ]; then
    print_red "The selected block device is mounted. Unmount the block device and try again. Exiting..."
    exit 1
fi

echo "Selected block device: $BLOCK_DEVICE"
exit 1

# Check if the selected block device is busy
# If the selected block device is busy, exit the script.
if [ $(lsof $BLOCK_DEVICE) ]; then
    print_red "The selected block device is busy. Close all the processes using the block device and try again. Exiting..."
    exit 1
fi

# Start the burning process
(
    dd bs=4M if=$ISO_FILE of=$BLOCK_DEVICE conv=fsync oflag=direct status=progress
) 2>&1 | stdbuf -o0 awk '/[0-9]+ bytes/ {print $0}' | dialog --progressbox "Burning ISO to $BLOCK_DEVICE..." $DIALOG_HEIGHT $DIALOG_WIDTH
# print_yellow "  dd bs=4M if=$ISO_FILE of=$BLOCK_DEVICE conv=fsync oflag=direct status=progress"

# Check if the burning process was successful
# If the burning process was successful, print a success message.
if [ $? -eq 0 ]; then
    print_green "ISO file burned successfully to $BLOCK_DEVICE."
else
    print_red "Failed to burn ISO file to $BLOCK_DEVICE."
fi

# End of script

