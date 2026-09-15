#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=${1:-${VERSION:-3.6.2}}
REVISION=${REVISION:-1}
NAME=pbvr
ARCH=amd64
SOURCE_DIR="${ROOT_DIR}/v${VERSION}_Linux"
BUILD_DIR="${ROOT_DIR}/debbuild"
STAGING_DIR="${BUILD_DIR}/${NAME}_${VERSION}-${REVISION}_${ARCH}"
PACKAGE_PATH="${BUILD_DIR}/${NAME}_${VERSION}-${REVISION}_${ARCH}.deb"
ICON_SOURCE="${SOURCE_DIR}/pbvr_client.app/usr/share/icons/hicolor/256x256/apps/pbvr_client.png"

if [ ! -d "${SOURCE_DIR}" ]; then
  echo "missing source directory: ${SOURCE_DIR}" >&2
  exit 1
fi

for required in pbvr_server pbvr_filter kvsml-converter pbvr_client.app; do
  if [ ! -e "${SOURCE_DIR}/${required}" ]; then
    echo "missing required file or directory: ${SOURCE_DIR}/${required}" >&2
    exit 1
  fi
done

if [ ! -f "${SOURCE_DIR}/pbvr_client.app/usr/bin/pbvr_client" ]; then
  echo "missing client binary: ${SOURCE_DIR}/pbvr_client.app/usr/bin/pbvr_client" >&2
  exit 1
fi

if [ ! -f "${ICON_SOURCE}" ]; then
  echo "missing client icon: ${ICON_SOURCE}" >&2
  exit 1
fi

rm -rf "${STAGING_DIR}"
mkdir -p \
  "${STAGING_DIR}/DEBIAN" \
  "${STAGING_DIR}/opt/pbvr/${VERSION}" \
  "${STAGING_DIR}/usr/bin" \
  "${STAGING_DIR}/usr/share/applications" \
  "${STAGING_DIR}/usr/share/icons/hicolor/256x256/apps"

cp -a "${SOURCE_DIR}/pbvr_server" "${STAGING_DIR}/opt/pbvr/${VERSION}/"
cp -a "${SOURCE_DIR}/pbvr_filter" "${STAGING_DIR}/opt/pbvr/${VERSION}/"
cp -a "${SOURCE_DIR}/kvsml-converter" "${STAGING_DIR}/opt/pbvr/${VERSION}/"
cp -a "${SOURCE_DIR}/pbvr_client.app" "${STAGING_DIR}/opt/pbvr/${VERSION}/"

cat > "${STAGING_DIR}/usr/bin/pbvr_server" <<EOF
#!/bin/sh
exec /opt/pbvr/${VERSION}/pbvr_server "\$@"
EOF

cat > "${STAGING_DIR}/usr/bin/pbvr_filter" <<EOF
#!/bin/sh
exec /opt/pbvr/${VERSION}/pbvr_filter "\$@"
EOF

cat > "${STAGING_DIR}/usr/bin/kvsml-converter" <<EOF
#!/bin/sh
exec /opt/pbvr/${VERSION}/kvsml-converter "\$@"
EOF

cat > "${STAGING_DIR}/usr/bin/pbvr_client" <<EOF
#!/bin/sh
APPDIR=/opt/pbvr/${VERSION}/pbvr_client.app
export APPDIR
export QT_QPA_PLATFORM=xcb
export QSG_RHI_BACKEND=opengl
export QT_XCB_GL_INTEGRATION=xcb_egl
export LD_LIBRARY_PATH="\${APPDIR}/usr/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
export QT_PLUGIN_PATH="\${APPDIR}/usr/plugins\${QT_PLUGIN_PATH:+:\${QT_PLUGIN_PATH}}"
export QML2_IMPORT_PATH="\${APPDIR}/usr/qml\${QML2_IMPORT_PATH:+:\${QML2_IMPORT_PATH}}"
cd "\${APPDIR}/usr/bin" || exit 1
exec "\${APPDIR}/usr/bin/pbvr_client" "\$@"
EOF

chmod 0755 \
  "${STAGING_DIR}/usr/bin/pbvr_server" \
  "${STAGING_DIR}/usr/bin/pbvr_filter" \
  "${STAGING_DIR}/usr/bin/kvsml-converter" \
  "${STAGING_DIR}/usr/bin/pbvr_client"

DESKTOP_SOURCE="${SOURCE_DIR}/pbvr_client.app/usr/share/applications/pbvr_client.desktop"
if [ ! -f "${DESKTOP_SOURCE}" ]; then
  DESKTOP_SOURCE="${SOURCE_DIR}/pbvr_client.app/pbvr_client.desktop"
fi
if [ ! -f "${DESKTOP_SOURCE}" ]; then
  echo "missing desktop file for pbvr_client" >&2
  exit 1
fi

if ! grep -qx 'Exec=pbvr_client' "${DESKTOP_SOURCE}"; then
  echo "desktop file does not launch the packaged pbvr_client wrapper: ${DESKTOP_SOURCE}" >&2
  exit 1
fi
if ! grep -qx 'Icon=pbvr_client' "${DESKTOP_SOURCE}"; then
  echo "desktop file does not reference the packaged pbvr_client icon: ${DESKTOP_SOURCE}" >&2
  exit 1
fi

cp "${DESKTOP_SOURCE}" "${STAGING_DIR}/usr/share/applications/pbvr_client.desktop"
chmod 0644 "${STAGING_DIR}/usr/share/applications/pbvr_client.desktop"

cp "${ICON_SOURCE}" \
  "${STAGING_DIR}/usr/share/icons/hicolor/256x256/apps/pbvr_client.png"
chmod 0644 "${STAGING_DIR}/usr/share/icons/hicolor/256x256/apps/pbvr_client.png"

cat > "${STAGING_DIR}/DEBIAN/control" <<EOF
Package: ${NAME}
Version: ${VERSION}-${REVISION}
Section: science
Priority: optional
Architecture: ${ARCH}
Maintainer: PBVR Packager <pbvr@example.invalid>
Depends: libc6 (>= 2.29), libdbus-1-3 (>= 1.9.14), libegl1, libfontconfig1 (>= 2.12.6), libfreetype6 (>= 2.9.1), libgcc-s1 (>= 3.0), libgl1, libglu1-mesa, libglx0, libgomp1 (>= 6), libharfbuzz0b (>= 2.1.1), libice6 (>= 1:1.0.0), libopengl0, libpcre2-16-0 (>= 10.22), libpng16-16 (>= 1.6.2-1), libsm6, libstdc++6 (>= 10), libx11-6, libx11-xcb1 (>= 2:1.6.9), libxcb-cursor0 (>= 0.0.99), libxcb-glx0, libxcb-icccm4 (>= 0.4.1), libxcb-image0 (>= 0.2.1), libxcb-keysyms1 (>= 0.4.0), libxcb-randr0 (>= 1.12), libxcb-render-util0, libxcb-render0, libxcb-shape0, libxcb-shm0 (>= 1.10), libxcb-sync1, libxcb-xfixes0, libxcb-xkb1, libxcb1 (>= 1.8), libxkbcommon-x11-0 (>= 0.5.0), libxkbcommon0 (>= 0.5.0), zlib1g (>= 1:1.2.0)
Homepage: https://ccsepbvr.github.io/apt-yum-pbvr/
Description: Binary distribution for PBVR
 PBVR command line tools and Qt client application.
EOF

dpkg-deb --build --root-owner-group "${STAGING_DIR}" "${PACKAGE_PATH}"
echo "${PACKAGE_PATH}"
