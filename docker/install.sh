#!/bin/sh -eu

# Installs the newest LDC release, the LLVM-based D compiler, from its GitHub
# releases. LDC publishes a linux tarball for both x86_64 and aarch64 with
# every release, and tracks the newest D frontend.
#
# github redirects the releases/latest URL to the tag of the newest release,
# so the version is read from where it is redirected to. That asks nothing of
# the API, which rate limits by IP and would make a build depend on how busy
# the runner's neighbours had been.

apt-get update
apt-get install --yes --no-install-recommends curl ca-certificates xz-utils

readonly LATEST_URL=$(curl --silent --output /dev/null \
  --write-out '%{redirect_url}' \
  https://github.com/ldc-developers/ldc/releases/latest)

# The tag carries a leading v that the tarball's name does not.
readonly LDC_TAG="${LATEST_URL##*/tag/}"
readonly LDC_VERSION="${LDC_TAG#v}"

if [ -z "${LDC_VERSION}" ]; then
  echo 'ERROR: could not resolve the newest LDC release' >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64)  readonly TARGET=x86_64 ;;
  aarch64) readonly TARGET=aarch64 ;;
  *)
    echo "Unsupported architecture $(uname -m)" >&2
    exit 1
    ;;
esac

readonly NAME="ldc2-${LDC_VERSION}-linux-${TARGET}"
curl --silent --fail --location --output "/tmp/${NAME}.tar.xz" \
  "https://github.com/ldc-developers/ldc/releases/download/${LDC_TAG}/${NAME}.tar.xz"

mkdir --parents /usr/local/lib
tar --extract --xz --file="/tmp/${NAME}.tar.xz" --directory=/usr/local/lib
mv "/usr/local/lib/${NAME}" /usr/local/lib/ldc
# The bin/ directory must stay next to the lib/ and import/ trees it was
# unpacked with, or the compiler cannot find druntime and phobos. So the
# binaries are linked onto the PATH rather than moved there.
ln --symbolic /usr/local/lib/ldc/bin/* /usr/local/bin/

rm "/tmp/${NAME}.tar.xz"
rm -rf /var/lib/apt/lists/*

# Records the D this image holds, in the shape every image shares. The
# version is the language's, not LDC's own: it is the version of the DMD
# frontend LDC is built on, which is what defines the D a kata can write.
# The installed compiler is asked, so the version is one the image can run
# rather than one written down when someone last edited this file. The second
# line of ldc2 --version reads "based on DMD v2.113.0 and LLVM 22.1.8".
readonly LANGUAGE_VERSION=$(ldc2 --version | sed --quiet 's/.*based on DMD v\([0-9][0-9.]*\).*/\1/p')

if [ -z "${LANGUAGE_VERSION}" ]; then
  echo 'Could not read a version from ldc2 --version' >&2
  exit 1
fi

cat > /versions.json <<EOF
{
  "language": {
    "name": "D",
    "version": "${LANGUAGE_VERSION}"
  },
  "test_frameworks": []
}
EOF
