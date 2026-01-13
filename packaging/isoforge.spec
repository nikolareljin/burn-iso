Name:           isoforge
Version:        %{version}
Release:        1%{?dist}
Summary:        TUI tool for downloading and flashing ISO images to USB
License:        MIT
URL:            https://github.com/nikolareljin/burn-iso
BuildArch:      noarch

Requires:       bash, dialog, curl, jq, coreutils, util-linux

%description
Isoforge provides a simple terminal UI for selecting and downloading distros,
flashing to USB, and creating Ventoy multi-ISO drives.

%prep
%autosetup -n %{name}-%{version}

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/isoforge
mkdir -p %{buildroot}/usr/share/isoforge/scripts
mkdir -p %{buildroot}/usr/share/man/man1

install -m 0755 inc/isoforge.sh %{buildroot}/usr/bin/isoforge
install -m 0644 config.json %{buildroot}/usr/share/isoforge/config.json
install -m 0644 VERSION %{buildroot}/usr/share/isoforge/VERSION
cp -a scripts/* %{buildroot}/usr/share/isoforge/scripts/
install -m 0644 docs/man/isoforge.1 %{buildroot}/usr/share/man/man1/isoforge.1

%files
/usr/bin/isoforge
/usr/share/isoforge/config.json
/usr/share/isoforge/VERSION
/usr/share/isoforge/scripts
/usr/share/man/man1/isoforge.1

%changelog
* Thu Jan 09 2026 Nikola Reljin <nikola.reljin@gmail.com> - 0.1.0-1
- Initial release
