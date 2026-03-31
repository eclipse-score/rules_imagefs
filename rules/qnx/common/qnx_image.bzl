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

load(":common/pkg.bzl", "qnx_build_inputs_from_pkg")

def _gen_main_build_file(
        ctx,
        extra_build_files,
        global_attrs = None):
    """
    Generates the main build file used to create a qnx6fs image.

    Args:
        ctx: Context.
        extra_build_files: extra build files to be appended
        global_attrs:
          Global options, apply to both the image and extra build files.
          Accepts a list of a mix of strings or dicts, to represent static
          options (e.g. -optional) or mapped values (e.g. block_size=4096)

    Returns:
        main_{}.build
    """
    file_name = "main_{}.build".format(ctx.attr.name)
    main_build_file = ctx.actions.declare_file(file_name)

    content = ""
    if global_attrs:
        for attr in global_attrs:
            if type(attr) == "string":
                content += "[{}]\n".format(attr)
            elif type(attr) == "dict":
                for key, value in attr.items():
                    content += "[{}={}]\n".format(key, value)
            else:
                fail("Unsupported attribute type '{}', must be string or dict".format(type(attr)))

    for build_file in extra_build_files:
        content += "[+include] {}\n".format(build_file.path)

    ctx.actions.write(main_build_file, content)

    return main_build_file

def gen_image_definition(
        ctx,
        srcs,
        global_attrs = None,
        extra_build_file = None,
        extra_build_files = []):
    """
    Process inputs for QNX image definition, return contents and builds files.

    Args:
        ctx: Rule context.
        srcs: Input srcs for FS, can be mix of DUI, rules_pkg, and regular.
        global_attrs: Attributes set globally on main build file.
        extra_build_file: Additional build file to be included.
        extra_build_files: Additional build files to be included after the
            extra_build_file.
    Returns:
        main_build_file: Main entrypoint QNX build file.
        build_files: QNX build files inluded in the main.
        fs_contents: Files to be included in the QNX image.
        expanded_repo_map: Expanded Bazel locations with paths of files to be
                           included.
    """

    build_files = []
    fs_contents = []

    # Add extra build files
    build_files.append(extra_build_file)
    build_files.extend(extra_build_files)

    # # Rules_pkg contents
    pkg_contents, pkg_build_file = qnx_build_inputs_from_pkg(
        ctx,
        srcs,
        per_file_attrs = None,
    )

    build_files.append(pkg_build_file)
    fs_contents.extend(pkg_contents)

    # Generate main build file which imports others
    main_build_file = _gen_main_build_file(
        ctx,
        build_files,
        global_attrs,
    )

    return main_build_file, build_files, fs_contents
