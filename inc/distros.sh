#!/usr/bin/env bash
# Linux distribution download URLs used by burn-iso scripts

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

  [BlackArch_amd64]="https://blackarch.org/iso/blackarch-linux-live-2025.04.01-x86_64.iso"
)
