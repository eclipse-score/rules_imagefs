#!/bin/sh

# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************

# Re-stages ext4 rule srcs into a private scratch directory, then truncates and
# formats the image.
# Usage: create_image.sh <coreutils> <mke2fs> <name> <size_file> <output> [D dest | F dest src | L dest target]...
set -eu

coreutils="$1"
shift
mke2fs="$1"
shift
name="$1"
shift
size_file="$1"
shift
output="$1"
shift

stage="$PWD/$name.stage"
rm -rf "$stage"
"$coreutils" mkdir -p "$stage"
trap 'rm -rf "$stage"' EXIT

while [ "$#" -gt 0 ]; do
    case "$1" in
        D)
            "$coreutils" mkdir -p "$stage/$2"
            shift 2
            ;;
        F)
            "$coreutils" cp "$3" "$stage/$2"
            shift 3
            ;;
        L)
            "$coreutils" ln -s "$3" "$stage/$2"
            shift 3
            ;;
        *)
            echo "create_image: unknown entry type '$1'" >&2
            exit 1
            ;;
    esac
done

read -r size_bytes < "$size_file"
"$coreutils" truncate -s "$size_bytes" "$output"
"$mke2fs" -q -t ext4 -O ^has_journal -d "$stage" "$output"
