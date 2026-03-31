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
This rule generates an Image File System (IFS) for QNX.

In order todo that, the user has to provide a main build file and supporting
files. The main build file will be used as entrypoint and can then include
other build files or perform other operations like packaging any file into the
created IFS.
"""

load(":common/common.bzl", "gen_image", "prep_inputs", "prep_output", _common_rule_attrs = "COMMON_RULES_ATTRS")

QNX_FS_TOOLCHAIN = "@score_rules_imagefs//toolchains/qnx:ifs_toolchain_type"

_attrs_ifs_rules = {}
_attrs_ifs_rules.update(_common_rule_attrs)
_attrs_ifs_rules.update({
    "search_roots": attr.string_list(
        default = [],
        doc = "List of paths for mkifs -r, each relative to the main build file's directory (or absolute).",
    ),
})

def _qnx_ifs_impl(ctx):
    """ Implementation function of qnx_ifs rule.

        This function will merge all .build files into main .build file and
        produce flashable QNX image.
    """

    out_image = prep_output(ctx, "ifs")
    main_build_file_string_path, inputs = prep_inputs(ctx)

    args = ctx.actions.args()
    args.add_all(
        ctx.attr.search_roots,
        before_each = "-r",
    )
    args.add_all([
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

qnx_ifs = rule(
    implementation = _qnx_ifs_impl,
    toolchains = [QNX_FS_TOOLCHAIN],
    attrs = _attrs_ifs_rules,
)
