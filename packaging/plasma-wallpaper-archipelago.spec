# SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
%global plugin_id io.github.himanishpuri.archipelago

Name:           plasma-wallpaper-archipelago
Version:        0.2.0
Release:        1%{?dist}
Summary:        Plasma wallpaper that grows a landscape around your desktop icons
License:        GPL-3.0-or-later
URL:            https://github.com/himanishpuri/archipelago
Source0:        archipelago-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  make
BuildRequires:  gettext
BuildRequires:  qt6-qtshadertools
Requires:       plasma-workspace >= 6.3
Requires:       plasma-desktop >= 6.3

%description
Archipelago is an animated Plasma 6 wallpaper. An environment engine tracks the
icons and widgets on the desktop and a theme draws a landscape around them:
the Beach theme grows sandy islands that merge, move and sink with the icons.

%prep
%autosetup -n archipelago-%{version}

%build
%make_build shaders mo

%install
mkdir -p %{buildroot}%{_datadir}/plasma/wallpapers/%{plugin_id}
cp -a package/. %{buildroot}%{_datadir}/plasma/wallpapers/%{plugin_id}/

%files
%license LICENSE
%doc README.md
%{_datadir}/plasma/wallpapers/%{plugin_id}/

%changelog
* Tue Nov 10 2026 himanishpuri <himanishpuri2203@gmail.com> - 0.2.0-1
- Environment engine with interchangeable themes
