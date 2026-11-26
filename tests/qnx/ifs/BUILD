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
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_pkg//pkg:mappings.bzl", "pkg_attributes", "pkg_files")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("@score_rules_imagefs//rules/qnx:ifs.bzl", "qnx_ifs")

# Everything here needs the QNX toolchains. Build and test it with
# `--config=x86_64-qnx-ifs`; other configurations skip these targets.

cc_binary(
    name = "hello",
    srcs = ["hello.c"],
    target_compatible_with = ["@platforms//os:qnx"],
)

pkg_files(
    name = "hello_files",
    srcs = [":hello"],
    attributes = pkg_attributes(mode = "0755"),
    prefix = "proc/boot",
    target_compatible_with = ["@platforms//os:qnx"],
)

qnx_ifs(
    name = "test_image",
    srcs = [":hello_files"],
    build_file = "image.build",
    target_compatible_with = ["@platforms//os:qnx"],
)

sh_test(
    name = "ifs_test",
    srcs = ["ifs_test.sh"],
    args = ["$(rootpath :test_image)"],
    data = [":test_image"],
    target_compatible_with = ["@platforms//os:qnx"],
)
