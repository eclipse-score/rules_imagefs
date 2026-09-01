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

load("@rules_pkg//pkg:mappings.bzl", "pkg_files", "pkg_mklink")
load("@score_rules_imagefs//rules/linux:ext4.bzl", "ext4")

pkg_files(
    name = "rootfs_files",
    srcs = ["hello.txt"],
    prefix = "etc",
)

pkg_mklink(
    name = "hello_link",
    link_name = "usr/share/hello.txt",
    target = "/etc/hello.txt",
)

ext4(
    name = "test_image",
    srcs = [
        ":hello_link",
        ":rootfs_files",
    ],
)

sh_test(
    name = "ext4_test",
    srcs = ["ext4_test.sh"],
    args = ["$(location :test_image)"],
    data = [":test_image"],
)
