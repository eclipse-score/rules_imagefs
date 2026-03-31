# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
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
This rule generates a QNX6 filesystem image using the QNX6 filesystem utility.

The user provides input files and configuration that define the filesystem
contents and structure. The QNX6 filesystem tool creates a filesystem image
based on this specification.
"""

load(":common/common.bzl", "gen_image", "prep_inputs", "prep_output", _common_rule_attrs = "COMMON_RULES_ATTRS")

QNX_FS_TOOLCHAIN = "@score_rules_imagefs//toolchains/qnx:qnx6fs_toolchain_type"

def _qnx6fs_impl(ctx):
    """ Implementation function of qnx6fs rule.

        This function invokes the QNX6 filesystem creation utility to generate
        a QNX6 filesystem image based on the provided inputs and configuration
        defined in the rule context.
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

qnx6fs = rule(
    implementation = _qnx6fs_impl,
    toolchains = [QNX_FS_TOOLCHAIN],
    attrs = _common_rule_attrs,
)
