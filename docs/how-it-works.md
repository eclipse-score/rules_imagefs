<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# How it works

This page explains how the module turns a few lines in `MODULE.bazel` into an
image. Read it to debug toolchain problems, to review the module, or before you
change it. You don't need it to build images.

## The pieces

The module has four layers:

| Layer | Location | Job |
|---|---|---|
| Rules | [rules/](../rules) | Declare `ext4`, `qnx_ifs`, `qnx6fs`, `fatfs`, and `diskimage`. Each rule turns `srcs` into an action that builds the image. |
| Toolchain types and providers | [toolchains/](../toolchains) | Declare one toolchain type for each image type. Define the config rules (`ext4_toolchain_config`, `ifs_toolchain_config`) that expose the tools to the rules. |
| Templates | [templates/](../templates) | Hold the `BUILD` file templates that the generated toolchain repositories use. |
| Module extension | [extensions/imagefs.bzl](../extensions/imagefs.bzl) | Reads `sdp` and `toolchain` tags and creates the repositories. |

## From tags to toolchains

When you add a `toolchain` tag to your `MODULE.bazel`, the extension runs these
steps:

1. For every `sdp` tag, it downloads and unpacks the archive with
   `http_archive`, under the tag's `name`.
1. If at least one `toolchain` tag has `type = "ext4"`, it creates the
   `e2fsprogs` repository, once. That repository holds the e2fsprogs 1.47.4
   source and the `BUILD` files that compile `mke2fs`.
1. For every `toolchain` tag, it creates a repository with the
   `imagefs_toolchain` repository rule. That rule expands a `BUILD` template
   into the repository:
   - For `target_os = "qnx"`, it uses [templates/qnx/BUILD.template](../templates/qnx/BUILD.template).
   - For `target_os = "linux"`, it uses [templates/linux/BUILD.template](../templates/linux/BUILD.template).
1. For every `ext4` toolchain tag, it also registers a `coreutils` download
   through `bazel_lib`, without registering it as a toolchain.

The expanded `BUILD` file contains a config target and a `toolchain` target:

- For QNX, `ifs_toolchain_config` points at the SDP targets `mkTYPE`,
  `host_dir`, `target_dir`, `host_all`, and `target_all`. The toolchain
  target is named `TYPE-CPU-qnx-sdp_VERSION` and requires the matching SDP
  version constraint.
- For ext4, `ext4_toolchain_config` points at `coreutils` and `mke2fs`. The
  toolchain target is named `ext4-CPU-OS`.

When you call `register_toolchains` for the generated target, Bazel can
select it for rules that declare the matching toolchain type.

## How a rule builds an image

### QNX rules

The QNX rules in [rules/qnx/](../rules/qnx) share one code path:

1. [common/pkg.bzl](../rules/qnx/common/pkg.bzl) reads the `rules_pkg`
   providers in `srcs` and writes a generated build file with one entry for
   each directory, file, and symbolic link.
1. [common/qnx_image.bzl](../rules/qnx/common/qnx_image.bzl) writes a main
   build file that includes your build files and the generated file.
1. [common/common.bzl](../rules/qnx/common/common.bzl) runs the SDP tool from
   the toolchain with the main build file and the output path as arguments. It
   sets the environment that [Build QNX images](qnx-images.md#environment-variables)
   describes.

`diskimage` differs because its tool doesn't understand includes. It
concatenates the build files with
[flatten_build_files.py](../rules/qnx/tools/flatten_build_files.py) instead.

### The ext4 rule

The ext4 rule doesn't use a build file. It passes the toolchain's `coreutils`
and `mke2fs` and a flat list of entries to
[create_image.sh](../rules/linux/tools/create_image.sh). Each entry is
`D destination` (directory), `F destination source` (file), or
`L destination target` (symbolic link). The script stages the entries in a
temporary directory, sizes and truncates the image file, and runs `mke2fs`. For
the sizing rule and options, see [Rule reference](rules.md#ext4).

The script uses only the toolchain's tools, so the result doesn't depend on
tools on the host `PATH`.

## How `mke2fs` is built

The [e2fsprogs repository rule](../rules/linux/tools/e2fsprogs.bzl) downloads
the e2fsprogs source archive and checks its SHA-256 checksum. It then writes
`BUILD` and `.bzl` files into the repository from
[templates/linux/tools/e2fsprogs/](../templates/linux/tools/e2fsprogs). Bazel
compiles `mke2fs` for the execution platform, so no e2fsprogs install is
needed. The module depends on `rules_cc_autoconf` for the configuration probes
and on `gawk` for generated code. Both are dependencies of the module, so they
resolve against the module's own repository mapping.

## Behavior to know about

- **No default toolchain.** The module registers no toolchain. You register
  the ones that you use.
- **Root module only.** The `imagefs` extension fails for non-root modules.
- **Fixed modification time.** The QNX build file generator writes a fixed
  `mtime`, so identical inputs produce identical build file entries.
