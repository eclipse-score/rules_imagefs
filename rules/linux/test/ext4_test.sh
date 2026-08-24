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

set -eu

image="$1"

content=$(DEBUGFS_PAGER=cat debugfs -R "cat /etc/hello.txt" "$image" 2>/dev/null)
test "$content" = "hello from ext4"

DEBUGFS_PAGER=cat debugfs -R "stat /etc/hello.txt" "$image" 2>&1 | grep -q "Type: regular"
DEBUGFS_PAGER=cat debugfs -R "stat /usr/share/hello.txt" "$image" 2>&1 | grep -q "Type: symlink"
DEBUGFS_PAGER=cat debugfs -R "stat /usr/share/hello.txt" "$image" 2>&1 | grep -q 'Fast link dest: "/etc/hello.txt"'

tune2fs -l "$image" 2>/dev/null | grep "Filesystem features:" | grep -qv "has_journal"
