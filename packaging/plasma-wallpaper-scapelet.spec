# SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
%global plugin_id io.github.himanishpuri.scapelet

Name:           plasma-wallpaper-scapelet
Version:        0.6.1
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
* Thu Nov 12 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.6.1-1
- City: the still part of the town is drawn once; a frame costs about a fifth of the GPU time
- Forest: about a fifth less GPU time per frame
- Developer tools: make bench, make same
* Wed Nov 11 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.6.0-1
- New theme: City, an old industrial town that opens a square around the icons
- Clicks on the empty desktop make the theme react; can be turned off
- Forest: winding footpaths, hikers and a woodcutter, each configurable
- Beach: old sailing ships and modern boats cross the sea
- Beach: no script error at start-up

* Wed Nov 11 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.5.0-1
- New theme: Forest, a paper-cut forest that opens a clearing around the icons
- Areas grow outward from their icon and ease in and out instead of popping
- Meadow: puff clouds with cast shadows, drifting clouds, one to three butterflies
- Cosmos: Milky Way, coloured stars with glow, filament nebula, slow drift
- Beach: kayak and gulls follow curved routes and cast shadows
- Shared settings are labelled in the words of each theme

* Wed Nov 11 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.4.1-1
- Require Plasma 6.3 in the plugin metadata
- Settings text is plain English; i18n() calls removed
- make lint fails on any qmllint warning

* Wed Nov 11 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.4.0-1
- New themes: Meadow (clouds over grass) and Cosmos (nebulae and constellations)

* Wed Nov 11 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.3.1-1
- Smooth gull flight with the battery saver on
- Drop the translation template; RPM builds with podman or docker

* Tue Nov 10 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.3.0-1
- Project renamed from Archipelago to Scapelet

* Tue Nov 10 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.2.0-1
- Environment engine with interchangeable themes
