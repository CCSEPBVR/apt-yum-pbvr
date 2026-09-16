#!/usr/bin/env bash

set -Eeuo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
apt_root="$repository_root/apt"
work_dir=""

cleanup() {
    if [[ -n "$work_dir" && -d "$work_dir" ]]; then
        rm -rf -- "$work_dir"
    fi
}
trap cleanup EXIT

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

if [[ "$#" -ne 1 ]]; then
    printf 'Usage: %s /path/to/pbvr_<version>_amd64.deb\n' "$0" >&2
    exit 2
fi

input_deb=$1
[[ -f "$input_deb" ]] || die "指定されたdebが存在しません: $input_deb"

missing_commands=()
for command_name in dpkg-deb dpkg-scanpackages apt-ftparchive gzip; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        missing_commands+=("$command_name")
    fi
done

if (( ${#missing_commands[@]} > 0 )); then
    printf 'Error: 必要なコマンドがありません: %s\n' "${missing_commands[*]}" >&2
    printf '必要なパッケージを用意してください: dpkg-dev、apt-utils、gzip\n' >&2
    printf '（dpkg-debがない場合はdpkgも必要です。）\n' >&2
    exit 1
fi

package_name=$(dpkg-deb -f "$input_deb" Package) || die "debのPackage情報を読み取れません: $input_deb"
architecture=$(dpkg-deb -f "$input_deb" Architecture) || die "debのArchitecture情報を読み取れません: $input_deb"
version=$(dpkg-deb -f "$input_deb" Version) || die "debのVersion情報を読み取れません: $input_deb"

[[ "$package_name" == "pbvr" ]] || die "Packageがpbvrではありません: $package_name"
[[ "$architecture" == "amd64" ]] || die "Architectureがamd64ではありません: $architecture"
[[ -n "$version" ]] || die "Versionが空です"

published_filename="pbvr_${version}_amd64.deb"
work_dir=$(mktemp -d -- "$repository_root/.apt-repository-update.XXXXXX")
staging_root="$work_dir/apt"
staging_pool="$staging_root/pool/main/p/pbvr"
packages_file="$staging_root/dists/stable/main/binary-amd64/Packages"
packages_gz_file="$staging_root/dists/stable/main/binary-amd64/Packages.gz"
release_file="$staging_root/dists/stable/Release"
release_output="$work_dir/Release"

mkdir -p -- "$(dirname -- "$packages_file")" "$staging_pool"
cp -- "$input_deb" "$staging_pool/$published_filename"

(
    cd -- "$staging_root"
    dpkg-scanpackages --arch amd64 pool /dev/null > "$packages_file"
)
gzip -n -c "$packages_file" > "$packages_gz_file"

apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=CCSEPBVR \
    -o APT::FTPArchive::Release::Label=PBVR \
    -o APT::FTPArchive::Release::Suite=stable \
    -o APT::FTPArchive::Release::Codename=stable \
    -o APT::FTPArchive::Release::Architectures=amd64 \
    -o APT::FTPArchive::Release::Components=main \
    -o 'APT::FTPArchive::Release::Description=PBVR APT repository' \
    release "$staging_root/dists/stable" > "$release_output"
mv -- "$release_output" "$release_file"

mapfile -t published_debs < <(find "$staging_pool" -maxdepth 1 -type f -name '*.deb' -print)
(( ${#published_debs[@]} == 1 )) || die "pool/main/p/pbvr/のdebが1ファイルではありません"
published_deb=${published_debs[0]}
[[ "$(basename -- "$published_deb")" == "$published_filename" ]] || die "公開ファイル名が想定と異なります"

package_stanza_count=$(awk '$1 == "Package:" { count++ } END { print count + 0 }' "$packages_file")
(( package_stanza_count == 1 )) || die "Packagesのパッケージ件数が1ではありません"

packages_field() {
    local field=$1
    awk -v field="$field" 'index($0, field ": ") == 1 {
        print substr($0, length(field) + 3)
        exit
    }' "$packages_file"
}

assert_equal() {
    local label=$1
    local expected=$2
    local actual=$3
    [[ "$actual" == "$expected" ]] || die "$labelが一致しません（expected=$expected actual=$actual）"
}

expected_size=$(stat -c '%s' "$published_deb")
expected_sha256=$(sha256sum "$published_deb" | awk '{print $1}')
assert_equal 'PackagesのPackage' "$package_name" "$(packages_field Package)"
assert_equal 'PackagesのVersion' "$version" "$(packages_field Version)"
assert_equal 'PackagesのArchitecture' "$architecture" "$(packages_field Architecture)"
assert_equal 'PackagesのFilename' "pool/main/p/pbvr/$published_filename" "$(packages_field Filename)"
assert_equal 'PackagesのSize' "$expected_size" "$(packages_field Size)"
assert_equal 'PackagesのSHA256' "$expected_sha256" "$(packages_field SHA256)"

decompressed_packages="$work_dir/Packages.decompressed"
gzip -cd "$packages_gz_file" > "$decompressed_packages"
cmp -s "$packages_file" "$decompressed_packages" || die 'Packages.gzの展開内容がPackagesと一致しません'

assert_release_field() {
    local field=$1
    local expected=$2
    grep -Fqx "$field: $expected" "$release_file" || die "Releaseの$fieldが正しくありません"
}

assert_release_field Origin CCSEPBVR
assert_release_field Label PBVR
assert_release_field Suite stable
assert_release_field Codename stable
assert_release_field Architectures amd64
assert_release_field Components main
assert_release_field Description 'PBVR APT repository'

release_entry() {
    local section=$1
    local relative_path=$2
    awk -v section="$section" -v relative_path="$relative_path" '
        $0 == section ":" { in_section = 1; next }
        in_section && $0 ~ /^[[:alnum:]][[:alnum:]]*:/ { in_section = 0 }
        in_section && NF >= 3 && $3 == relative_path {
            print $1 " " $2
            exit
        }
    ' "$release_file"
}

validate_release_entry() {
    local section=$1
    local relative_path=$2
    local file=$3
    local entry
    local listed_checksum
    local listed_size
    local actual_checksum
    local actual_size

    entry=$(release_entry "$section" "$relative_path")
    [[ -n "$entry" ]] || die "Releaseに$relative_pathの$sectionエントリがありません"
    read -r listed_checksum listed_size <<< "$entry"
    actual_size=$(stat -c '%s' "$file")
    assert_equal "Releaseの$section $relative_path サイズ" "$actual_size" "$listed_size"

    case "$section" in
        MD5Sum) actual_checksum=$(md5sum "$file" | awk '{print $1}') ;;
        SHA1) actual_checksum=$(sha1sum "$file" | awk '{print $1}') ;;
        SHA256) actual_checksum=$(sha256sum "$file" | awk '{print $1}') ;;
        SHA512) actual_checksum=$(sha512sum "$file" | awk '{print $1}') ;;
        *) die "未対応のチェックサム種別です: $section" ;;
    esac
    assert_equal "Releaseの$section $relative_path チェックサム" "$actual_checksum" "$listed_checksum"
}

validate_release_entry MD5Sum main/binary-amd64/Packages "$packages_file"
validate_release_entry MD5Sum main/binary-amd64/Packages.gz "$packages_gz_file"
validate_release_entry SHA1 main/binary-amd64/Packages "$packages_file"
validate_release_entry SHA1 main/binary-amd64/Packages.gz "$packages_gz_file"
validate_release_entry SHA256 main/binary-amd64/Packages "$packages_file"
validate_release_entry SHA256 main/binary-amd64/Packages.gz "$packages_gz_file"
validate_release_entry SHA512 main/binary-amd64/Packages "$packages_file"
validate_release_entry SHA512 main/binary-amd64/Packages.gz "$packages_gz_file"

[[ ! -e "$staging_root/InRelease" ]] || die 'InReleaseは作成しないでください'
[[ ! -e "$staging_root/Release.gpg" ]] || die 'Release.gpgは作成しないでください'
[[ ! -e "$staging_root/Packages" ]] || die 'APT直下のPackagesは作成しないでください'
[[ ! -e "$staging_root/Packages.gz" ]] || die 'APT直下のPackages.gzは作成しないでください'

previous_apt="$work_dir/previous-apt"
if [[ -e "$apt_root" || -L "$apt_root" ]]; then
    mv -- "$apt_root" "$previous_apt" || die '既存のAPTリポジトリを退避できません'
fi

if ! mv -- "$staging_root" "$apt_root"; then
    if [[ -e "$previous_apt" || -L "$previous_apt" ]]; then
        mv -- "$previous_apt" "$apt_root" || true
    fi
    die '新しいAPTリポジトリを配置できません'
fi

mapfile -t live_debs < <(find "$apt_root/pool/main/p/pbvr" -maxdepth 1 -type f -name '*.deb' -print)
if (( ${#live_debs[@]} != 1 )); then
    rm -rf -- "$apt_root"
    if [[ -e "$previous_apt" || -L "$previous_apt" ]]; then
        mv -- "$previous_apt" "$apt_root" || true
    fi
    die '更新後のpool/main/p/pbvr/のdebが1ファイルではありません'
fi

rm -rf -- "$previous_apt"
printf 'APTリポジトリを更新しました: %s\n' "$apt_root"
printf '公開バージョン: %s\n' "$version"
