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
Supports QNX zzzzzzzzzzzzzzzzzzzzzzzzzzzzFS image generation from rules_pkg providers. Filters rules_pkg
targets from srcs and generates QNX build file entries from their contents.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_pkg//pkg:providers.bzl", "PackageDirsInfo", "PackageFilegroupInfo", "PackageFilesInfo", "PackageSymlinkInfo")

_DEFAULT_FILE_MODE = "0644"
_DEFAULT_DIR_MODE = "0755"
_DEFAULT_LINK_MODE = "0777"
_DEFAULT_UID = 0
_DEFAULT_GID = 0
_FIXED_MTIME = "2021-03-22-20:20:00"

def _get_pkg_attr(attributes, field, default):
    """Get a single field from a pkg_attributes dict, defaulting if absent or None."""
    if attributes == None:
        return default
    value = attributes.get(field)
    if value == None:
        return default
    return value

def qnx_build_inputs_from_pkg(ctx, pkg_srcs, per_file_attrs = None):
    """Generate QNX build file and collect contents from rules_pkg sources.

    Args:
        ctx: Rule context.
        pkg_srcs: List of targets providing rules_pkg providers.
        per_file_attrs: Optional list of extra attributes for file entries
            (e.g. ["-optional"]).
    Returns:
        fs_contents: List of Files to include in the image.
        build_file: Generated QNX build file.
    """
    content = "[mtime={}]\n".format(_FIXED_MTIME)
    fs_contents = []
    extra_attrs_str = ""
    if per_file_attrs:
        extra_attrs_str = " ".join(per_file_attrs) + " "

    for src in pkg_srcs:
        # Normalize to lists of (provider, label) tuples regardless of source type
        if PackageFilegroupInfo in src:
            pfgi = src[PackageFilegroupInfo]
            files_list = pfgi.pkg_files
            dirs_list = pfgi.pkg_dirs
            symlinks_list = pfgi.pkg_symlinks
        elif (
            PackageFilesInfo in src or
            PackageDirsInfo in src or
            PackageSymlinkInfo in src
        ):
            # src.label is included in the manually-constructed tuples to match the (provider, label) structure from PackageFilegroupInfo.
            files_list = [(src[PackageFilesInfo], src.label)] if PackageFilesInfo in src else []
            dirs_list = [(src[PackageDirsInfo], src.label)] if PackageDirsInfo in src else []
            symlinks_list = [(src[PackageSymlinkInfo], src.label)] if PackageSymlinkInfo in src else []
        else:
            fail("Target {} does not provide any rules_pkg provider".format(src.label))

        # Process directories
        for pdi, _label in dirs_list:
            mode = _get_pkg_attr(pdi.attributes, "mode", _DEFAULT_DIR_MODE)
            uid = _get_pkg_attr(pdi.attributes, "uid", _DEFAULT_UID)
            gid = _get_pkg_attr(pdi.attributes, "gid", _DEFAULT_GID)
            for dir_path in pdi.dirs:
                dir_path = paths.normalize(dir_path)
                content += "[type=dir uid={} gid={} perms={}] /{}\n".format(
                    uid,
                    gid,
                    mode,
                    dir_path,
                )

        # Process files
        for pfi, _label in files_list:
            mode = _get_pkg_attr(pfi.attributes, "mode", _DEFAULT_FILE_MODE)
            uid = _get_pkg_attr(pfi.attributes, "uid", _DEFAULT_UID)
            gid = _get_pkg_attr(pfi.attributes, "gid", _DEFAULT_GID)
            for dest, src_file in sorted(pfi.dest_src_map.items()):
                dest = dest.lstrip("/")
                content += "[{}uid={} gid={} perms={}] /{}={}\n".format(
                    extra_attrs_str,
                    uid,
                    gid,
                    mode,
                    dest,
                    src_file.path,
                )
                fs_contents.append(src_file)

        # Process symlinks
        for psi, _label in symlinks_list:
            mode = _get_pkg_attr(psi.attributes, "mode", _DEFAULT_LINK_MODE)
            uid = _get_pkg_attr(psi.attributes, "uid", _DEFAULT_UID)
            gid = _get_pkg_attr(psi.attributes, "gid", _DEFAULT_GID)
            dest = paths.normalize(psi.destination)
            content += "[type=link uid={} gid={} perms={}] /{}={}\n".format(
                uid,
                gid,
                mode,
                dest,
                psi.target,
            )

    build_file = ctx.actions.declare_file("{}_pkg_content.build".format(ctx.attr.name))
    ctx.actions.write(build_file, content)

    return fs_contents, build_file
