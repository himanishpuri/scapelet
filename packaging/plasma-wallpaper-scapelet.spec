# SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
%global plugin_id io.github.himanishpuri.scapelet

Name:           plasma-wallpaper-scapelet
Version:        0.4.0
Release:        1%{?dist}
Summary:        Plasma wallpaper that grows a landscape around your desktop icons
License:        GPL-3.0-or-later
URL:            https://github.com/himanishpuri/scapelet
Source0:        scapelet-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  make
BuildRequires:  qt6-qtshadertools
Requires:       plasma-workspace >= 6.3
Requires:       plasma-desktop >= 6.3

%description
Scapelet is an animated Plasma 6 wallpaper. An environment engine tracks the
icons and widgets on the desktop and a theme draws a landscape around them:
Beach grows sandy islands, Meadow gathers clouds over grass and Cosmos lights
nebulae and constellations.

%prep
%autosetup -n scapelet-%{version}

%build
%make_build shaders

%install
mkdir -p %{buildroot}%{_datadir}/plasma/wallpapers/%{plugin_id}
cp -a package/. %{buildroot}%{_datadir}/plasma/wallpapers/%{plugin_id}/

%files
%license LICENSE
%doc README.md
%{_datadir}/plasma/wallpapers/%{plugin_id}/

%changelog
* Wed Nov 11 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.4.0-1
- New themes: Meadow (clouds over grass) and Cosmos (nebulae and constellations)

* Wed Nov 11 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.3.1-1
- Smooth gull flight with the battery saver on
- Drop the translation template; RPM builds with podman or docker

* Tue Nov 10 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.3.0-1
- Project renamed from Archipelago to Scapelet

* Tue Nov 10 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.2.0-1
- Environment engine with interchangeable themes
