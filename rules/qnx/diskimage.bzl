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

load(":common/common.bzl", "gen_image", "prep_inputs", "prep_output", _common_rule_attrs = "COMMON_RULES_ATTRS")

QNX_FS_TOOLCHAIN = "@score_rules_imagefs//toolchains/qnx:diskimage_toolchain_type"

diskimage_attrs = {}
diskimage_attrs.update(_common_rule_attrs)
diskimage_attrs.update({
    "gpt_enabled": attr.bool(
        default = False,
        doc = "When True, passes -g to diskimage to generate a GPT (GUID Partition Table) disk image.",
    ),
})

def _diskimage_impl(ctx):
    """ Implementation function of diskimage rule.

        This function uses the QNX diskimage utility to create a composite
        disk image from the provided build file specification.
    """
    out_image = prep_output(ctx)
    main_build_file_string_path, inputs = prep_inputs(ctx)

    args = ctx.actions.args()

    if ctx.attr.gpt_enabled:
        args.add("-g")

    args.add_all([
        "-o",
        out_img.path,
        "-c",
        main_build_file_string_path,
    ])

    return gen_image(
        ctx,
        inputs = inputs,
        outputs = [out_image],
        arguments = [args],
        image_tc_type = QNX_FS_TOOLCHAIN,
    )

diskimage = rule(
    implementation = _diskimage_impl,
    toolchains = [QNX_FS_TOOLCHAIN],
    attrs = diskimage_attrs,
)
