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

"""Bazel rule for injecting overlays into existing ext4 filesystem images."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_pkg//pkg:pkg.bzl", "pkg_tar")

def _ext4_overlay_inject_impl(ctx):
    """Implementation of ext4_overlay_inject rule."""

    if not ctx.attr.partition:
        fail("partition attribute is required")

    if not ctx.attr.image:
        fail("image attribute is required")

    # Create output image
    out_image = ctx.actions.declare_file(
        ctx.attr.out if ctx.attr.out else "{}.img".format(ctx.attr.name),
    )

    # Build overlay tar if srcs provided
    overlay_tar = None
    if ctx.attr.srcs:
        # Create intermediate tar target
        tar_name = "{}_overlay".format(ctx.attr.name)
        pkg_tar(
            name = tar_name,
            srcs = ctx.attr.srcs,
            package_dir = ctx.attr.package_dir,
        )

        # Get the tar file from the intermediate target
        overlay_tar = ctx.files._overlay_tar[0]

    # Build arguments
    args = ctx.actions.args()
    args.add("--image", ctx.file.image.path)
    args.add("--partition", ctx.attr.partition)
    args.add("--output", out_image.path)

    if overlay_tar:
        args.add("--tar", overlay_tar.path)

    if ctx.attr.no_space_check:
        args.add("--no-space-check")

    # Run the inject_overlay tool
    ctx.actions.run(
        executable = ctx.executable._inject_tool,
        arguments = [args],
        inputs = [ctx.file.image] + ([overlay_tar] if overlay_tar else []),
        outputs = [out_image],
        mnemonic = "InjectExt4Overlay",
        progress_message = "Injecting overlay into {}".format(ctx.file.image.short_path),
    )

    return [DefaultInfo(files = depset([out_image]))]

ext4_overlay_inject = rule(
    implementation = _ext4_overlay_inject_impl,
    attrs = {
        "image": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Source ext4 disk image to inject overlay into",
        ),
        "partition": attr.int(
            mandatory = True,
            doc = "Partition number to inject overlay into (1-based)",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Files to include in the overlay",
        ),
        "package_dir": attr.string(
            default = "/",
            doc = "Directory prefix for overlay files",
        ),
        "out": attr.string(
            doc = "Output image filename (defaults to {name}.img)",
        ),
        "no_space_check": attr.bool(
            default = False,
            doc = "Skip free space verification",
        ),
        "_inject_tool": attr.label(
            default = "//rules/linux/tools/overlay:inject_overlay",
            executable = True,
            cfg = "exec",
        ),
        "_overlay_tar": attr.label(
            allow_files = [".tar"],
        ),
    },
    doc = """Injects an overlay into an existing ext4 partition image.
    
This rule uses debugfs to inject files into an ext4 filesystem without
requiring loop mounts or root privileges, making it suitable for CI/CD
pipelines running in containers without CAP_SYS_ADMIN.

Example:
    ext4_overlay_inject(
        name = "custom_raspbian",
        image = "//images:raspbian_base",
        partition = 2,
        srcs = [
            "//config:config_files",
            "//apps:my_app",
        ],
        package_dir = "/opt/myapp",
    )
""",
)
