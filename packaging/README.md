# PBVR packaging

## DEB package (Ubuntu 20.04 and later)

The DEB package supports Ubuntu 20.04 and later on `amd64`. The PBVR 3.6.2
release is installed under `/opt/pbvr/3.6.2/`; wrappers for `pbvr_server`,
`pbvr_filter`, `kvsml-converter`, and `pbvr_client` are installed in
`/usr/bin`.

The package also installs the desktop entry at
`/usr/share/applications/pbvr_client.desktop` and the PBVR client icon at
`/usr/share/icons/hicolor/256x256/apps/pbvr_client.png`.

The runtime dependencies are based on the `NEEDED` entries of the 3.6.2 ELF
executables, bundled Qt libraries, and Qt plugins. In particular,
`libglu1-mesa` is declared because 3.6.2 requires `libGLU.so.1` from the
system instead of shipping that library in the release directory.

### Build

With `v3.6.2_Linux/` at the repository root, run:

```sh
./packaging/build-deb.sh
```

The result is:

```text
debbuild/pbvr_3.6.2-1_amd64.deb
```

An explicit version can still be supplied when building another local release:

```sh
./packaging/build-deb.sh 3.6.2
```

### Local installation and upgrade

Install the package and its declared dependencies with:

```sh
sudo apt install ./debbuild/pbvr_3.6.2-1_amd64.deb
```

If PBVR 3.6.1 is already installed, the same command upgrades the `pbvr`
package to 3.6.2. Do not remove 3.6.1 first; `dpkg` handles the package
upgrade and the versioned `/opt/pbvr/` directories accordingly.

### Check the installation

```sh
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n' pbvr
command -v pbvr_server pbvr_filter kvsml-converter pbvr_client
grep -E '^(Exec|Icon)=' /usr/share/applications/pbvr_client.desktop
test -f /usr/share/icons/hicolor/256x256/apps/pbvr_client.png
```

Run the four installed entry points:

```sh
pbvr_server --help
pbvr_filter --help
kvsml-converter --help
pbvr_client
```

The last command starts the Qt GUI. The same GUI can be started from the
desktop application menu; its desktop entry uses `Exec=pbvr_client` and
`Icon=pbvr_client`.

### Uninstall

```sh
sudo apt remove pbvr
test ! -e /usr/bin/pbvr_server
test ! -e /usr/bin/pbvr_filter
test ! -e /usr/bin/kvsml-converter
test ! -e /usr/bin/pbvr_client
find /opt/pbvr -maxdepth 2 \( -type f -o -type l \) -print 2>/dev/null
```

The final command should produce no output for package-owned PBVR files. If it
shows files from an older manual installation, inspect them before removing
anything manually.

This task covers local DEB packaging only. Updating the public APT repository,
APT metadata, GitHub Pages, `gh-pages`, commits, and pushes is out of scope.

# PBVR RPM packaging memo

This directory contains the files used to build a binary RPM from the PBVR
Linux release directory.

## Inputs

Place the upstream binary directory at the repository root before building:

```sh
v3.6.2_Linux/
```

The directory name must match the PBVR version. For example, version `3.6.2`
uses `v3.6.2_Linux`.

The expected files are:

```text
v3.6.2_Linux/
  pbvr_server
  pbvr_filter
  kvsml-converter
  pbvr_client.app/
```

Do not commit `v*_Linux/` to the normal source branch. Keep the original binary
archive outside Git, such as in GitHub Releases or project storage.

## Build

Run the build script with the version:

```sh
packaging/build-rpm.sh 3.6.2
```

The output RPM will be written under:

```text
rpmbuild/RPMS/x86_64/
```

`rpmbuild/` is a local build output directory and should not be committed.

## RPM verification

Verify the package before installing it. The checks below include the RPM
digest, metadata, dependencies, packaged files, the unsigned state, and the
desktop entry and SVG icon:

```sh
RPM=./rpmbuild/RPMS/x86_64/pbvr-3.6.2-1.el8.x86_64.rpm
rpm -K "$RPM"
rpm -qip "$RPM"
rpm -qp --requires "$RPM"
rpm -qp --provides "$RPM"
rpm -qlp "$RPM"
rpm -qlp "$RPM" | grep -Fx /usr/share/icons/hicolor/scalable/apps/pbvr_client.svg
rpmlint "$RPM"

CHECK_DIR=$(mktemp -d)
trap 'rm -rf "$CHECK_DIR"' EXIT
(cd "$CHECK_DIR" && rpm2cpio "$OLDPWD/$RPM" | cpio -idm)
desktop-file-validate "$CHECK_DIR/usr/share/applications/pbvr_client.desktop"
test -s "$CHECK_DIR/usr/share/icons/hicolor/scalable/apps/pbvr_client.svg"
```

## Local install test

Install the generated RPM directly first:

```sh
sudo dnf install ./rpmbuild/RPMS/x86_64/pbvr-3.6.2-1.el8.x86_64.rpm
```

Check the command wrappers:

```sh
which pbvr_client
which pbvr_server
which pbvr_filter
which kvsml-converter
```

Run the binaries that can be tested in the current environment. If the client
GUI is available, also run:

```sh
pbvr_client
```

Uninstall after testing:

```sh
sudo dnf remove pbvr
```

## Publish to yum repository

After the local install test passes, update the yum repository on `gh-pages`.
Preserve older RPMs if they should remain installable.

```sh
git switch gh-pages
cp /path/to/pbvr-3.6.2-1.el8.x86_64.rpm yum/
createrepo_c yum
git add yum
git commit -m "Add PBVR 3.6.2 RPM repository metadata"
```

The `yum/` directory belongs on `gh-pages`, not on the normal source branch.

## Notes

The spec disables debug package generation, stripping, and build-id link
generation. Build-id links are disabled because bundled AppDir libraries can
share build IDs with OS packages, causing `/usr/lib/.build-id` conflicts during
installation.

The RPM installs the release under `/opt/pbvr/<version>/` and creates wrappers
in `/usr/bin`. `pbvr_client` is a wrapper that starts:

```text
/opt/pbvr/<version>/pbvr_client.app/usr/bin/pbvr_client
```

The wrapper sets `APPDIR`, `QT_PLUGIN_PATH`, and `LD_LIBRARY_PATH` for the
bundled Qt application.
