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

"""Bazel rule for creating an ext4 filesystem image on Linux."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_pkg//pkg:providers.bzl", "PackageDirsInfo", "PackageFilegroupInfo", "PackageFilesInfo", "PackageSymlinkInfo")

EXT4_TOOLCHAIN = "@score_rules_imagefs//toolchains/linux:ext4_toolchain_type"

def _pkg_entry_args(ctx):
    """Builds the flat "D dest | F dest src | L dest target" argv consumed by create_image.sh."""
    args = []
    inputs = []

    for src in ctx.attr.srcs:
        files_list = []
        dirs_list = []
        symlinks_list = []
        if PackageFilegroupInfo in src:
            provider = src[PackageFilegroupInfo]
            files_list = provider.pkg_files
            dirs_list = provider.pkg_dirs
            symlinks_list = provider.pkg_symlinks
        elif (
            PackageFilesInfo in src or
            PackageDirsInfo in src or
            PackageSymlinkInfo in src
        ):
            files_list = [(src[PackageFilesInfo], src.label)] if PackageFilesInfo in src else []
            dirs_list = [(src[PackageDirsInfo], src.label)] if PackageDirsInfo in src else []
            symlinks_list = [(src[PackageSymlinkInfo], src.label)] if PackageSymlinkInfo in src else []
        else:
            fail("Target {} does not provide a rules_pkg provider".format(src.label))

        for pdi, _ in dirs_list if type(dirs_list) == "list" else []:
            for directory in pdi.dirs:
                destination = paths.normalize(directory).lstrip("/")
                args.extend(["D", destination])

        for pfi, _ in files_list if type(files_list) == "list" else []:
            for destination, source in sorted(pfi.dest_src_map.items()):
                destination = paths.normalize(destination).lstrip("/")
                parent = paths.dirname(destination)
                if parent:
                    args.extend(["D", parent])
                args.extend(["F", destination, source.path])
                inputs.append(source)

        for psi, _ in symlinks_list if type(symlinks_list) == "list" else []:
            destination = paths.normalize(psi.destination).lstrip("/")
            parent = paths.dirname(destination)
            if parent:
                args.extend(["D", parent])
            args.extend(["L", destination, psi.target])

    return inputs, args

def _create_image(ctx, tool_info, entry_inputs, entry_args, out_image):
    """Stages srcs and truncates/formats the image, in a single pass, via the static //rules/linux/tools:create_image script."""
    args = ctx.actions.args()
    args.add(tool_info.coreutils)
    args.add(tool_info.mke2fs)
    args.add(ctx.attr.name)
    args.add(out_image.path)
    args.add_all(entry_args)

    ctx.actions.run(
        executable = ctx.executable._create_image_tool,
        arguments = [args],
        inputs = entry_inputs,
        outputs = [out_image],
        tools = tool_info.tools,
        mnemonic = "CreateExt4Image",
        progress_message = "Creating ext4 image {}".format(out_image.short_path),
    )

def _ext4_impl(ctx):
    if ctx.attr.out and "/" in ctx.attr.out:
        fail("Output file must be a filename without path components, got: {}".format(ctx.attr.out))

    out_image = ctx.actions.declare_file(ctx.attr.out if ctx.attr.out else "{}.ext4".format(ctx.attr.name))
    entry_inputs, entry_args = _pkg_entry_args(ctx)

    tool_info = ctx.toolchains[EXT4_TOOLCHAIN].ext4_toolchain_info

    _create_image(ctx, tool_info, entry_inputs, entry_args, out_image)

    return [DefaultInfo(files = depset([out_image]))]

ext4 = rule(
    implementation = _ext4_impl,
    exec_compatible_with = ["@platforms//os:linux"],
    toolchains = [EXT4_TOOLCHAIN],
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            doc = "rules_pkg targets providing files, directories, and symlinks.",
        ),
        "out": attr.string(
            default = "",
            doc = "Optional output filename without path components.",
        ),
        "_create_image_tool": attr.label(
            default = Label("//rules/linux/tools:create_image"),
            cfg = "exec",
            executable = True,
        ),
    },
)
