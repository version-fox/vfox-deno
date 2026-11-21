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

# The repository dev container (see docs/development.md): a Linux userland that
# is the same on every host. It carries the Go toolchain the end-to-end suite is
# built with, and the Lua tools, vfox and the workflow linters at the versions
# the workflows pin, so `stylua`, `lua-language-server`, `vfox plugin test`,
# `license-eye`, `actionlint` and `go test` run here as they do in CI.
#
# The image is multi-arch (linux/amd64 and linux/arm64); install-tools.sh picks
# the asset for the architecture and checks its SHA-256 digest.

FROM golang:1.27.3

ARG STYLUA_VERSION=2.5.2
ARG LUA_LANGUAGE_SERVER_VERSION=3.19.1
ARG VFOX_VERSION=1.1.0

RUN set -o errexit -o nounset; \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        zip; \
    rm --recursive --force /var/lib/apt/lists/*

COPY install-tools.sh /tmp/install-tools.sh
RUN set -o errexit -o nounset; \
    bash /tmp/install-tools.sh; \
    rm --force /tmp/install-tools.sh
