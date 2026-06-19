Name:           pbvr
Version:        %{?pbvr_version}%{!?pbvr_version:3.6.1}
Release:        1%{?dist}
Summary:        PBVR binary distribution

License:        Proprietary
URL:            https://ccsepbvr.github.io/apt-yum-pbvr/
BuildArch:      x86_64

Source0:        pbvr-%{version}.tar.gz

%global debug_package %{nil}
%global __strip /bin/true
%global _build_id_links none

Requires:       glibc
Requires:       libstdc++
Requires:       libgcc
Requires:       libgomp
Requires:       zlib
Requires:       openssl-libs
Requires:       mesa-libGL
Requires:       libglvnd-glx
Requires:       libglvnd-opengl
Requires:       libX11
Requires:       libXext
Requires:       freetype
Requires:       fontconfig

%description
PBVR command line tools and Qt client application.

%prep
%setup -q

%build
# Binary-only package.

%install
rm -rf %{buildroot}

install -d %{buildroot}/opt/pbvr/%{version}
cp -a v%{version}_Linux/pbvr_server %{buildroot}/opt/pbvr/%{version}/
cp -a v%{version}_Linux/pbvr_filter %{buildroot}/opt/pbvr/%{version}/
cp -a v%{version}_Linux/kvsml-converter %{buildroot}/opt/pbvr/%{version}/
cp -a v%{version}_Linux/pbvr_client.app %{buildroot}/opt/pbvr/%{version}/

install -d %{buildroot}%{_bindir}

cat > %{buildroot}%{_bindir}/pbvr_server <<'EOF'
#!/bin/sh
exec /opt/pbvr/%{version}/pbvr_server "$@"
EOF

cat > %{buildroot}%{_bindir}/pbvr_filter <<'EOF'
#!/bin/sh
exec /opt/pbvr/%{version}/pbvr_filter "$@"
EOF

cat > %{buildroot}%{_bindir}/kvsml-converter <<'EOF'
#!/bin/sh
exec /opt/pbvr/%{version}/kvsml-converter "$@"
EOF

cat > %{buildroot}%{_bindir}/pbvr_client <<'EOF'
#!/bin/sh
APPDIR=/opt/pbvr/%{version}/pbvr_client.app
export APPDIR
export QT_PLUGIN_PATH="${APPDIR}/usr/plugins${QT_PLUGIN_PATH:+:${QT_PLUGIN_PATH}}"
export LD_LIBRARY_PATH="${APPDIR}/usr/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
cd "${APPDIR}/usr/bin" || exit 1
exec "${APPDIR}/usr/bin/pbvr_client" "$@"
EOF

chmod 0755 \
  %{buildroot}%{_bindir}/pbvr_server \
  %{buildroot}%{_bindir}/pbvr_filter \
  %{buildroot}%{_bindir}/kvsml-converter \
  %{buildroot}%{_bindir}/pbvr_client

install -d %{buildroot}%{_datadir}/applications
install -m 0644 v%{version}_Linux/pbvr_client.app/usr/share/applications/pbvr_client.desktop \
  %{buildroot}%{_datadir}/applications/pbvr_client.desktop

%files
%dir /opt/pbvr
%dir /opt/pbvr/%{version}
/opt/pbvr/%{version}/pbvr_server
/opt/pbvr/%{version}/pbvr_filter
/opt/pbvr/%{version}/kvsml-converter
/opt/pbvr/%{version}/pbvr_client.app
%{_bindir}/pbvr_server
%{_bindir}/pbvr_filter
%{_bindir}/kvsml-converter
%{_bindir}/pbvr_client
%{_datadir}/applications/pbvr_client.desktop

%changelog
* Fri Jun 19 2026 PBVR Packager <pbvr@example.invalid> - 3.6.1-1
- Package PBVR 3.6.1 Linux binaries.
