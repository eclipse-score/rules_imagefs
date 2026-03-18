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

load("@rules_pkg//pkg:providers.bzl", "PackageDirsInfo", "PackageFilegroupInfo", "PackageFilesInfo", "PackageSymlinkInfo")
load(":common/qnx_image.bzl", "gen_image_definition")

QNX_FS_TOOLCHAIN = "@score_rules_imagefs//toolchains/qnx:ifs_toolchain_type"

def _qnx_ifs_impl(ctx):
    """ Implementation function of qnx_ifs rule.

        This function will merge all .build files into main .build file and
        produce flashable QNX image.
    """
    inputs = []
    extra_build_files = []

    # Choose output filename
    out_name = ctx.attr.out if ctx.attr.out else "{}.{}".format(ctx.attr.name, ctx.attr.extension)
    if "/" in out_name:
        fail("qnx_ifs.out must be a filename without path components, got: {}".format(out_name))

    out_ifs = ctx.actions.declare_file(out_name)
    ifs_tool_info = ctx.toolchains[QNX_FS_TOOLCHAIN].ifs_toolchain_info

    main_build_file, build_files, fs_contents = gen_image_definition(
        ctx,
        srcs = ctx.attr.all_files,
        extra_build_file = ctx.file.build_file,
        extra_build_files = ctx.files.extra_build_files,
    )

    inputs.append(main_build_file)
    inputs.extend(build_files)
    inputs.extend(fs_contents)

    args = ctx.actions.args()

    args.add_all(
        ctx.files.search_paths,
        before_each = "-r",
    )

    args.add_all([
        main_build_file_2.path,
        out_ifs.path,
    ])

    ctx.actions.run(
        outputs = [out_ifs],
        inputs = inputs,
        arguments = [args],
        executable = ifs_tool_info.executable,
        env = ifs_tool_info.env,
        tools = ifs_tool_info.tools,
    )

    return [
        DefaultInfo(files = depset([out_ifs])),
    ]

qnx_ifs = rule(
    implementation = _qnx_ifs_impl,
    toolchains = [QNX_FS_TOOLCHAIN, TAR_TOOLCHAIN],
    attrs = {
        "all_files": attr.label_list(
            mandatory = True,
        ),
        "build_file": attr.label(
            allow_single_file = True,
            doc = "Single label that points to the main build file (entrypoint)",
            mandatory = True,
        ),
        "extension": attr.string(
            default = "ifs",
            doc = "Extension for the generated IFS image. Manipulating this extensions is a workaround for IPNext startup code limitation, when interpreting ifs images. This attribute will either disappear or will be replaced by toolchain configuration in order to keep output files consistent.",
        ),
        "extra_build_files": attr.label_list(
            allow_files = True,
            default = [],
            doc = "Additional build files to be included after the main build_file.",
        ),
        "out": attr.string(
            default = "",
            doc = "Optional explicit output filename (no path). If empty, uses name + '.' + extension.",
        ),
        "search_roots": attr.string_list(
            default = [],
            doc = "List of paths for mkifs -r, each relative to the main build file's directory (or absolute).",
        ),
    },
)
