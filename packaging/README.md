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
