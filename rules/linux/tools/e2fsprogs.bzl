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

""" Repository rule that downloads and extracts an archive (e.g. e2fsprogs source). """

def _impl(rctx):
    """Implementation of the mke2fs repository rule.

    Args:
        rctx: The repository context.
    """
    rctx.download_and_extract(
        url = rctx.attr.url,
        sha256 = rctx.attr.sha256,
        strip_prefix = rctx.attr.strip_prefix,
    )

    # Create main build file of the package
    rctx.template(
        "BUILD",
        rctx.attr._mke2fs_build_file,
        {},
    )

    # Create autoconf build file of the package
    rctx.template(
        "bazel/BUILD",
        rctx.attr._autoconf_build_file,
        {},
    )

    # Create autoconf bzl file of the package
    rctx.template(
        "bazel/autoconf.bzl",
        rctx.attr._autoconf_bzl_file,
        {},
    )

    # Create codegen bzl file of the package
    rctx.template(
        "bazel/codegen.bzl",
        rctx.attr._codegen_bzl_file,
        {},
    )

    # Copy every file next to the resources package's BUILD file (not just a
    # hardcoded list) so new resource files don't require touching this rule.
    resources_dir = rctx.path(rctx.attr._resources_marker).dirname
    for entry in resources_dir.readdir():
        if entry.basename != "BUILD":
            rctx.file("bazel/{}".format(entry.basename), rctx.read(entry))

e2fsprogs = repository_rule(
    implementation = _impl,
    attrs = {
        "url": attr.string(
            mandatory = True,
            doc = "URL of the archive to download.",
        ),
        "sha256": attr.string(
            mandatory = False,
            default = "",
            doc = "Expected SHA-256 checksum of the archive.",
        ),
        "strip_prefix": attr.string(
            mandatory = False,
            default = "",
            doc = "Directory prefix to strip from the extracted archive.",
        ),
        "_mke2fs_build_file": attr.label(
            allow_single_file = True,
            mandatory = False,
            default = Label("@score_rules_imagefs//templates/linux/tools/e2fsprogs:mke2fs.BUILD.template"),
            doc = "BUILD file to apply to the extracted archive contents.",
        ),
        "_autoconf_build_file": attr.label(
            allow_single_file = True,
            mandatory = False,
            default = Label("@score_rules_imagefs//templates/linux/tools/e2fsprogs/bazel:autoconf.BUILD.template"),
            doc = "BUILD file to apply to the extracted archive contents.",
        ),
        "_autoconf_bzl_file": attr.label(
            allow_single_file = True,
            mandatory = False,
            default = Label("@score_rules_imagefs//templates/linux/tools/e2fsprogs/bazel:autoconf_defs.bzl.template"),
            doc = "Bazel file to apply to the extracted archive contents.",
        ),
        "_codegen_bzl_file": attr.label(
            allow_single_file = True,
            mandatory = False,
            default = Label("@score_rules_imagefs//templates/linux/tools/e2fsprogs/bazel:codegen.bzl.template"),
            doc = "Bazel file to apply to the extracted archive contents.",
        ),
        "_resources_marker": attr.label(
            allow_single_file = True,
            mandatory = False,
            default = Label("@score_rules_imagefs//templates/linux/tools/e2fsprogs/resources:BUILD"),
            doc = "Anchor file used to locate the resources directory; every sibling file there is copied into bazel/.",
        ),
    },
)
