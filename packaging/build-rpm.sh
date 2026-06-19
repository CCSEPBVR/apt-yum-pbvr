#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=${1:-${VERSION:-3.6.1}}
NAME=pbvr
TOPDIR="${ROOT_DIR}/rpmbuild"
TMPDIR="${TOPDIR}/tmp"
SOURCE_DIR="${ROOT_DIR}/v${VERSION}_Linux"
SOURCE_ARCHIVE="${TOPDIR}/SOURCES/${NAME}-${VERSION}.tar.gz"

if [ ! -d "${SOURCE_DIR}" ]; then
  echo "missing source directory: ${SOURCE_DIR}" >&2
  exit 1
fi

mkdir -p \
  "${TOPDIR}/BUILD" \
  "${TOPDIR}/BUILDROOT" \
  "${TOPDIR}/RPMS" \
  "${TOPDIR}/SOURCES" \
  "${TOPDIR}/SPECS" \
  "${TOPDIR}/SRPMS" \
  "${TMPDIR}"

tar -C "${ROOT_DIR}" \
  --transform "s,^,${NAME}-${VERSION}/," \
  -czf "${SOURCE_ARCHIVE}" \
  "v${VERSION}_Linux"

cp "${ROOT_DIR}/packaging/${NAME}.spec" "${TOPDIR}/SPECS/${NAME}.spec"

rpmbuild \
  --define "_topdir ${TOPDIR}" \
  --define "_tmppath ${TMPDIR}" \
  --define "pbvr_version ${VERSION}" \
  -ba "${TOPDIR}/SPECS/${NAME}.spec"

find "${TOPDIR}/RPMS" -type f -name "${NAME}-${VERSION}-*.rpm" -print
