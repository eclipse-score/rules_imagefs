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

"""
This rule generates a disk image for QNX using the diskimage utility.

The user provides a main build file that describes the disk layout (partitions,
filesystems, etc.). The diskimage tool creates a composite disk image from this
specification.
"""

load(":common/common.bzl", "gen_image", "prep_output", _common_rule_attrs = "COMMON_RULES_ATTRS")
load(":common/qnx_image.bzl", "gen_image_definition")

QNX_FS_TOOLCHAIN = "@score_rules_imagefs//toolchains/qnx:diskimage_toolchain_type"

diskimage_attrs = {}
diskimage_attrs.update(_common_rule_attrs)
diskimage_attrs.update({
    "gpt_enabled": attr.bool(
        default = False,
        doc = "When True, passes -g to diskimage to generate a GPT (GUID Partition Table) disk image.",
    ),
    "_flatten_tool": attr.label(
        default = Label("//rules/qnx/tools:flatten_build_files"),
        cfg = "exec",
        executable = True,
    ),
})

def _diskimage_impl(ctx):
    """ Implementation function of diskimage rule.

        This function uses the QNX diskimage utility to create a composite
        disk image from the provided build file specification.

        The QNX `diskimage` host tool only understands a disk-layout build
        file (cylinders/heads/partitions/...); it does not understand the
        mkifs-style "[+include] <path>" directive emitted by the shared
        build-file generator, nor the file-placement (mtime/uid/gid) build
        file that the shared pkg helper generates for filesystem content.
        So the user-provided build file(s) are concatenated directly here,
        while the partition image files referenced from `srcs` are still
        staged as action inputs via `fs_contents`.
    """
    out_image = prep_output(ctx)
    _main_build_file, _build_files, fs_contents = gen_image_definition(
        ctx,
        srcs = ctx.attr.srcs,
        extra_build_file = ctx.file.build_file,
        extra_build_files = ctx.files.extra_build_files,
    )

    disk_build_files = [ctx.file.build_file] + ctx.files.extra_build_files
    flat_build_file = ctx.actions.declare_file("{}_flat.build".format(ctx.attr.name))
    flatten_args = ctx.actions.args()
    flatten_args.add("--output", flat_build_file)
    flatten_args.add_all(disk_build_files)
    ctx.actions.run(
        executable = ctx.executable._flatten_tool,
        arguments = [flatten_args],
        inputs = disk_build_files,
        outputs = [flat_build_file],
        mnemonic = "QnxDiskimageFlattenBuildFile",
    )

    args = ctx.actions.args()

    if ctx.attr.gpt_enabled:
        args.add("-g")

    args.add_all([
        "-o",
        out_image.path,
        "-c",
        flat_build_file.path,
    ])

    return gen_image(
        ctx,
        inputs = fs_contents + [flat_build_file],
        outputs = [out_image],
        arguments = [args],
        image_tc_type = QNX_FS_TOOLCHAIN,
    )

diskimage = rule(
    implementation = _diskimage_impl,
    toolchains = [QNX_FS_TOOLCHAIN],
    attrs = diskimage_attrs,
)
