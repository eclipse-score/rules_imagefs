#!/bin/bash
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

# Boots the IFS image in QEMU and waits until the hello application prints its
# message on the serial console.
# Usage: ifs_test.sh <ifs image>

set -eu

image="$1"
expected="hello from qnx ifs"
timeout_seconds=60
log="${TEST_TMPDIR:-/tmp}/qemu_serial.log"

if ! command -v qemu-system-x86_64 >/dev/null; then
    echo "qemu-system-x86_64 not found in PATH" >&2
    exit 1
fi

# QNX 8.0 crashes early in boot with `-cpu host`, so always use a fixed CPU
# model. Fall back to software emulation where KVM isn't available, e.g. in
# nested VMs.
cpu_model="Cascadelake-Server-v5"
if [ -w /dev/kvm ]; then
    accel_args=(-enable-kvm -cpu "$cpu_model")
else
    echo "KVM not available, using software emulation"
    accel_args=(-cpu "$cpu_model")
fi

: >"$log"
qemu-system-x86_64 \
    "${accel_args[@]}" \
    -m 256M \
    -smp 2 \
    -display none \
    -monitor none \
    -no-reboot \
    -serial "file:$log" \
    -kernel "$image" &
qemu_pid=$!
trap 'kill "$qemu_pid" 2>/dev/null || true; wait "$qemu_pid" 2>/dev/null || true' EXIT

for _ in $(seq "$timeout_seconds"); do
    if grep -q "$expected" "$log"; then
        echo "Found '$expected' on the serial console"
        exit 0
    fi
    if ! kill -0 "$qemu_pid" 2>/dev/null; then
        echo "QEMU exited before the application printed its message" >&2
        break
    fi
    sleep 1
done

echo "Did not find '$expected' on the serial console. Serial output:" >&2
cat "$log" >&2
exit 1
