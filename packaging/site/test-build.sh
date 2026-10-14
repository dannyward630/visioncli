#!/bin/sh
# Exercise the site builder without network access, real signing keys, or package tooling.
set -eu

root=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat > "$tmp/bin/gh" <<'SH'
#!/bin/sh
pattern=
dest=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p) pattern=$2; shift 2 ;;
    -D) dest=$2; shift 2 ;;
    *) shift ;;
  esac
done
case "$pattern" in
  '*.deb') : > "$dest/visioncli.deb" ;;
  '*.rpm')
    if [ "${TEST_HAS_RPM:-no}" = yes ]; then
      : > "$dest/visioncli.rpm"
    else
      exit 1
    fi
    ;;
esac
SH

cat > "$tmp/bin/gpg" <<'SH'
#!/bin/sh
case " $* " in
  *" --list-secret-keys "*) printf 'sec:u:2048:1:TESTKEY:0:0::::\n'; exit 0 ;;
  *" --export "*) printf 'fixture public key\n'; exit 0 ;;
esac
output=
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then
    output=$2
    shift 2
  else
    shift
  fi
done
if [ -n "$output" ]; then
  mkdir -p "$(dirname "$output")"
  printf 'fixture signature\n' > "$output"
fi
SH

cat > "$tmp/bin/apt-ftparchive" <<'SH'
#!/bin/sh
case "$1" in
  packages)
    printf 'Package: visioncli-linux\nArchitecture: amd64\n\nPackage: visioncli-linux\nArchitecture: arm64\n'
    ;;
  release) printf 'Origin: VisionCLI\n' ;;
esac
SH

cat > "$tmp/bin/rpmsign" <<'SH'
#!/bin/sh
exit 0
SH

cat > "$tmp/bin/createrepo_c" <<'SH'
#!/bin/sh
mkdir -p "$2/repodata"
printf '<repomd/>\n' > "$2/repodata/repomd.xml"
SH

chmod +x "$tmp/bin/gh" "$tmp/bin/gpg" "$tmp/bin/apt-ftparchive" \
  "$tmp/bin/rpmsign" "$tmp/bin/createrepo_c"

for has_rpm in no yes; do
  out="$tmp/site-$has_rpm"
  TEST_HAS_RPM=$has_rpm PATH="$tmp/bin:$PATH" PACKAGES_GPG_PRIVATE_KEY=fixture \
    sh "$root/packaging/site/build.sh" v0.10.5 "$out" >/dev/null

  grep -Fq 'Debian / Ubuntu' "$out/index.html"
  if [ "$has_rpm" = yes ]; then
    grep -Fq 'Fedora / RHEL / openSUSE' "$out/index.html"
    [ -f "$out/visioncli.repo" ]
  else
    if grep -Fq 'Fedora / RHEL / openSUSE' "$out/index.html"; then
      echo 'dnf instructions remained for a release without RPM files' >&2
      exit 1
    fi
    [ ! -e "$out/visioncli.repo" ]
  fi
done

echo 'Site builder RPM/no-RPM checks passed.'
