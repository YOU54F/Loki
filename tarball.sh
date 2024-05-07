#!/bin/bash

set -eu
# arm64-apple-darwin23
declare build_type="${1}"

declare tarball_filename="/tmp/${build_type}.tar.xz"
tar --directory='/tmp' --create --file=- 'loki' | xz --threads='0' --compress -9 > "${tarball_filename}"
sha256sum "${tarball_filename}" | sed 's|/tmp/||' > "${tarball_filename}.sha256"