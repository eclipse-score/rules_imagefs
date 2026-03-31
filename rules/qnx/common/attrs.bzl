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
Common attribute definitions for QNX image generation Bazel rules.

This module defines a shared attribute dictionary (`COMMON_RULES_ATTRS`) used
across rules responsible for generating QNX IFS images. These attributes
standardize how input files, build definitions, and output artifacts are
specified and handled within the rule implementations.

Attributes:
    all_files (label_list, mandatory):
        Collection of input targets contributing to the filesystem image.
        This may include DUI files, `rules_pkg` outputs, and regular files.

    build_file (label, mandatory):
        Label pointing to the main QNX build file (entry point). Must resolve
        to a single file.

    extension (string, default = "ifs"):
        File extension for the generated IFS image. This exists primarily as a
        workaround for limitations in IPNext startup code when interpreting IFS
        images. This attribute is expected to be deprecated or replaced by a
        toolchain-based configuration in the future to ensure consistency.

    extra_build_files (label_list, default = []):
        Additional build files to be included after the main `build_file`.
        These are appended in order and allow modularization of build logic.

    out (string, default = ""):
        Optional explicit name for the output file (must not include path
        components). If not provided, the output filename is derived as:
        `<rule_name>.<extension>`.
"""

COMMON_RULES_ATTRS = {
    "srcs": attr.label_list(
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
}
