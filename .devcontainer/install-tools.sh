#!/usr/bin/env bash
# Copyright 2026 Han Li and contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Installs the tools that the lint and test workflows pin, for the architecture
# of the image: stylua, lua-language-server, vfox, skywalking-eyes and actionlint.
# Each release archive is checked against the SHA-256 digest that GitHub publishes
# for it. Change a version and its digest together, and the workflow that uses it.
set -o errexit -o nounset -o pipefail

: "${STYLUA_VERSION:?}"
: "${LUA_LANGUAGE_SERVER_VERSION:?}"
: "${VFOX_VERSION:?}"

work="$(mktemp --directory)"
trap 'rm --recursive --force "$work"' EXIT

# download <url> <sha256> <file>: fetches url into file and fails unless its digest matches.
download() {
    curl --fail --silent --show-error --location --output "$3" "$1"
    echo "$2  $3" | sha256sum --check
}

case "$(dpkg --print-architecture)" in
    amd64)
        stylua_asset=stylua-linux-x86_64.zip
        stylua_sha256=bcb0d855e91f102f28a370e850f8566b3b44b79e6274d806ea5246837c0fd5ab
        luals_asset="lua-language-server-${LUA_LANGUAGE_SERVER_VERSION}-linux-x64.tar.gz"
        luals_sha256=e9235d2d72ef55bc41cf8c99cda2ed64777682024b4bb81f5dea425060c5cbb8
        vfox_dir="vfox_${VFOX_VERSION}_linux_x86_64"
        vfox_sha256=3b33c3c468b27bc17aecf0d6d3af24fe49fe204972984904a136a47b402a0ee4
        ;;
    arm64)
        stylua_asset=stylua-linux-aarch64.zip
        stylua_sha256=0ef2ebf0b7e5a652b65c4cb96c6d9ffb3981a98547de3c764465bbf54a8d761a
        luals_asset="lua-language-server-${LUA_LANGUAGE_SERVER_VERSION}-linux-arm64.tar.gz"
        luals_sha256=abd2572e8fc929dc838a81ffb8473c5bce0bf39bfe8edb4b120b3b623176ce83
        vfox_dir="vfox_${VFOX_VERSION}_linux_aarch64"
        vfox_sha256=e702e057dfe588200727dfb3cf786d181b13f015cbcc9e13679a3edcfd07e430
        ;;
    *)
        echo "unsupported architecture $(dpkg --print-architecture)" >&2
        exit 1
        ;;
esac

# The digests above are for the pinned versions only; a different version
# needs its own digests, which the workflows must match.
if [[ "$STYLUA_VERSION" != "2.5.2" || "$LUA_LANGUAGE_SERVER_VERSION" != "3.19.1" || "$VFOX_VERSION" != "1.1.0" ]]; then
    echo "the digests in install-tools.sh are for stylua 2.5.2, LuaLS 3.19.1 and vfox 1.1.0" >&2
    exit 1
fi

download "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/${stylua_asset}" \
    "$stylua_sha256" "$work/stylua.zip"
unzip -q "$work/stylua.zip" -d /usr/local/bin
chmod 0755 /usr/local/bin/stylua

download "https://github.com/LuaLS/lua-language-server/releases/download/${LUA_LANGUAGE_SERVER_VERSION}/${luals_asset}" \
    "$luals_sha256" "$work/luals.tar.gz"
mkdir --parents /opt/lua-language-server
tar --extract --gzip --file "$work/luals.tar.gz" --directory /opt/lua-language-server
ln --symbolic --force /opt/lua-language-server/bin/lua-language-server /usr/local/bin/lua-language-server

download "https://github.com/version-fox/vfox/releases/download/v${VFOX_VERSION}/${vfox_dir}.tar.gz" \
    "$vfox_sha256" "$work/vfox.tar.gz"
tar --extract --gzip --file "$work/vfox.tar.gz" --directory /usr/local/bin --strip-components=1 "${vfox_dir}/vfox"

GOBIN=/usr/local/bin go install github.com/apache/skywalking-eyes/cmd/license-eye@v0.9.0
GOBIN=/usr/local/bin go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12

stylua --version
lua-language-server --version
vfox --version
license-eye --version
actionlint -version
