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

""" Module rule for defining Image FileSystem toolchains in Bazel.
"""

def _impl(rctx):
    """ Implementation of the gcc_toolchain repository rule.

    Args:
        rctx: The repository context.
    """
    if rctx.attr.tc_os == "qnx":
        rctx.template(
            "BUILD",
            rctx.attr._qnx_toolchain_build,
            {
                "%{tc_pkg_repo}": rctx.attr.tc_pkg_repo,
                "%{tc_cpu}": rctx.attr.tc_cpu,
                "%{tc_os}": rctx.attr.tc_os,
                "%{sdp_version}": "sdp_{}".format(rctx.attr.sdp_version),
                "%{tc_type}": rctx.attr.tc_type,
            },
        )
    elif rctx.attr.tc_os == "linux":
        rctx.template(
            "BUILD",
            rctx.attr._linux_toolchain_build,
            {
                "%{tc_pkg_repo}": rctx.attr.tc_pkg_repo,
                "%{tc_cpu}": rctx.attr.tc_cpu,
                "%{tc_os}": rctx.attr.tc_os,
                "%{coreutils_pkg_repo}": rctx.attr.coreutils_pkg_repo,
                "%{tc_type}": rctx.attr.tc_type,
            },
        )
    else:
        fail("Unsupported target OS: {}".format(rctx.attr.tc_os))

imagefs_toolchain = repository_rule(
    implementation = _impl,
    attrs = {
        "tc_pkg_repo": attr.string(doc = "The label name of toolchain tarball."),
        "tc_cpu": attr.string(doc = "Target platform CPU."),
        "tc_os": attr.string(doc = "Target platform OS."),
        "sdp_version": attr.string(doc = "SDP version number"),
        "license_path": attr.string(doc = "Lincese path"),
        "license_info_variable": attr.string(doc = "License info variable name (custom settings)"),
        "license_info_value": attr.string(doc = "License info value (custom settings)"),
        "tc_type": attr.string(doc = "Image FileSystem type: ifs, qnx6fs, fatfs, diskimage or ext4"),
        "coreutils_pkg_repo": attr.string(doc = "Repo providing a ':coreutils' file target (e.g. generated via bazel_lib's register_coreutils_toolchains). Only used when tc_os == 'linux'."),
        "_linux_toolchain_build": attr.label(
            default = "@score_rules_imagefs//templates/linux:BUILD.template",
            doc = "Path to the Bazel BUILD file template for the toolchain.",
        ),
        "_qnx_toolchain_build": attr.label(
            default = "@score_rules_imagefs//templates/qnx:BUILD.template",
            doc = "Path to the Bazel BUILD file template for the toolchain.",
        ),
    },
)
