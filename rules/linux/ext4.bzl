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

def _shell_quote(value):
    return "'{}'".format(value.replace("'", "'\"'\"'"))

def _pkg_entries(ctx):
    commands = []
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

        if type(dirs_list) == "list":
            for pdi, _ in dirs_list:
                for directory in pdi.dirs:
                    destination = paths.normalize(directory).lstrip("/")
                    commands.append("mkdir -p {}/{}".format("$stage", _shell_quote(destination)))

        if type(files_list) == "list":
            for pfi, _ in files_list:
                for destination, source in sorted(pfi.dest_src_map.items()):
                    destination = paths.normalize(destination).lstrip("/")
                    parent = paths.dirname(destination)
                    commands.append("mkdir -p {}/{}".format("$stage", _shell_quote(parent)))
                    commands.append("cp {} {}/{}".format(
                        _shell_quote(source.path),
                        "$stage",
                        _shell_quote(destination),
                    ))
                    inputs.append(source)

        if type(symlinks_list) == "list":
            for psi, _ in symlinks_list:
                destination = paths.normalize(psi.destination).lstrip("/")
                parent = paths.dirname(destination)
                commands.append("mkdir -p {}/{}".format("$stage", _shell_quote(parent)))
                commands.append("ln -s {} {}/{}".format(
                    _shell_quote(psi.target),
                    "$stage",
                    _shell_quote(destination),
                ))

    return inputs, commands

def _ext4_impl(ctx):
    if ctx.attr.out and "/" in ctx.attr.out:
        fail("Output file must be a filename without path components, got: {}".format(ctx.attr.out))

    out_image = ctx.actions.declare_file(ctx.attr.out if ctx.attr.out else "{}.ext4".format(ctx.attr.name))
    inputs, entry_commands = _pkg_entries(ctx)
    script = ctx.actions.declare_file("{}_make_ext4.sh".format(ctx.attr.name))

    script_content = """#!/bin/sh
set -eu
stage="$PWD/{name}.stage"
output="$PWD/{output}"
rm -rf "$stage"
mkdir -p "$stage"
trap 'rm -rf "$stage"' EXIT
{entries}
content_bytes=$(du -sb "$stage" | cut -f1)
size_bytes=$((content_bytes + content_bytes / 10 + 16777216))
size_bytes=$(((size_bytes + 4095) / 4096 * 4096))
truncate -s "$size_bytes" "$output"
mke2fs -q -t ext4 -O ^has_journal -d "$stage" "$output"
""".format(
        name = ctx.attr.name,
        output = out_image.path,
        entries = "\n".join(entry_commands),
    )
    ctx.actions.write(script, script_content, is_executable = True)

    ctx.actions.run(
        executable = script,
        inputs = inputs,
        outputs = [out_image],
        mnemonic = "CreateExt4Image",
        progress_message = "Creating ext4 image {}".format(out_image.short_path),
    )
    return [DefaultInfo(files = depset([out_image]))]

ext4 = rule(
    implementation = _ext4_impl,
    exec_compatible_with = ["@platforms//os:linux"],
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            doc = "rules_pkg targets providing files, directories, and symlinks.",
        ),
        "out": attr.string(
            default = "",
            doc = "Optional output filename without path components.",
        ),
    },
)
