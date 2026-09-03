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

""" Toolchain provider implementation for the ext4 filesystem image rule.
"""

Ext4ToolchainInfo = provider(
    doc = "Executables for generating ext4 filesystem images.",
    fields = ["mke2fs", "coreutils", "tools"],
)

def _ext4_toolchain_config_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            ext4_toolchain_info = Ext4ToolchainInfo(
                mke2fs = ctx.executable.mke2fs,
                coreutils = ctx.file.coreutils,
                tools = depset(
                    [ctx.executable.mke2fs, ctx.file.coreutils],
                    transitive = [
                        ctx.attr.mke2fs.default_runfiles.files,
                        ctx.attr.coreutils.default_runfiles.files,
                    ],
                ),
            ),
        ),
    ]

ext4_toolchain_config = rule(
    implementation = _ext4_toolchain_config_impl,
    attrs = {
        "mke2fs": attr.label(
            cfg = "exec",
            executable = True,
            mandatory = True,
            doc = "Executable target providing the mke2fs tool. No hermetic prebuilt is available; build from e2fsprogs source (e.g. via rules_foreign_cc) or wrap a distro binary.",
        ),
        "coreutils": attr.label(
            cfg = "exec",
            allow_single_file = True,
            mandatory = True,
            doc = "File invoked as '<coreutils> <subcommand> args...' (du, cp, mkdir, ln, truncate). Can be a multicall binary (e.g. bazel_lib's prebuilt uutils coreutils, which isn't wrapped as a Bazel-executable target) or a small dispatcher wrapping host tools.",
        ),
    },
)
