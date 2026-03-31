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
This rule generates a FAT File System image for QNX using mkfatfsimg.

The user provides a main build file and supporting files. The main build file
is used as the entrypoint for mkfatfsimg to create the FAT filesystem image.
"""

load(":common/common.bzl", "gen_image", "prep_inputs", "prep_output", _common_rule_attrs = "COMMON_RULES_ATTRS")

QNX_FS_TOOLCHAIN = "@score_rules_imagefs//toolchains/qnx:fatfs_toolchain_type"

def _fatfs_impl(ctx):
    """ Implementation function of _fatfs rule.

        This function will merge all .build files into main .build file and
        produce flashable QNX image.
    """
    out_image = prep_output(ctx)
    main_build_file_string_path, inputs = prep_inputs(ctx)

    args = ctx.actions.args()
    args.add_all([
        "-n",
        main_build_file_string_path,
        out_image.path,
    ])

    return gen_image(
        ctx,
        inputs = inputs,
        outputs = [out_image],
        arguments = [args],
        image_tc_type = QNX_FS_TOOLCHAIN,
    )

fatfs = rule(
    implementation = _fatfs_impl,
    toolchains = [QNX_FS_TOOLCHAIN],
    attrs = _common_rule_attrs,
)
