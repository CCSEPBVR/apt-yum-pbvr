#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=${1:-${VERSION:-3.6.1}}
REVISION=${REVISION:-1}
NAME=pbvr
ARCH=amd64
SOURCE_DIR="${ROOT_DIR}/v${VERSION}_Linux"
BUILD_DIR="${ROOT_DIR}/debbuild"
STAGING_DIR="${BUILD_DIR}/${NAME}_${VERSION}-${REVISION}_${ARCH}"
PACKAGE_PATH="${BUILD_DIR}/${NAME}_${VERSION}-${REVISION}_${ARCH}.deb"

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

rm -rf "${STAGING_DIR}"
mkdir -p \
  "${STAGING_DIR}/DEBIAN" \
  "${STAGING_DIR}/opt/pbvr/${VERSION}" \
  "${STAGING_DIR}/usr/bin" \
  "${STAGING_DIR}/usr/share/applications"

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

if [ -f "${SOURCE_DIR}/pbvr_client.app/usr/share/applications/pbvr_client.desktop" ]; then
  cp "${SOURCE_DIR}/pbvr_client.app/usr/share/applications/pbvr_client.desktop" \
    "${STAGING_DIR}/usr/share/applications/pbvr_client.desktop"
elif [ -f "${SOURCE_DIR}/pbvr_client.app/usr/share/application/pbvr_client.desktop" ]; then
  cp "${SOURCE_DIR}/pbvr_client.app/usr/share/application/pbvr_client.desktop" \
    "${STAGING_DIR}/usr/share/applications/pbvr_client.desktop"
elif [ -f "${SOURCE_DIR}/pbvr_client.app/pbvr_client.desktop" ]; then
  cp "${SOURCE_DIR}/pbvr_client.app/pbvr_client.desktop" \
    "${STAGING_DIR}/usr/share/applications/pbvr_client.desktop"
else
  echo "missing desktop file for pbvr_client" >&2
  exit 1
fi

chmod 0644 "${STAGING_DIR}/usr/share/applications/pbvr_client.desktop"

cat > "${STAGING_DIR}/DEBIAN/control" <<EOF
Package: ${NAME}
Version: ${VERSION}-${REVISION}
Section: science
Priority: optional
Architecture: ${ARCH}
Maintainer: PBVR Packager <pbvr@example.invalid>
Depends: libc6, libstdc++6, libgcc-s1, libgomp1, zlib1g, libgl1, libglx0, libopengl0, libx11-6, libxext6, libfontconfig1, libfreetype6
Homepage: https://ccsepbvr.github.io/apt-yum-pbvr/
Description: PBVR binary distribution
 PBVR command line tools and Qt client application.
EOF

dpkg-deb --build --root-owner-group "${STAGING_DIR}" "${PACKAGE_PATH}"
echo "${PACKAGE_PATH}"
