<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# Configure toolchains

Every image rule needs a toolchain that provides the tools to build the image.
The module doesn't register any toolchain by default, so you must declare and
register one for each image type that you use. This page shows how to do that
with the `imagefs` module extension, and how to define an ext4 toolchain
yourself.

For a step-by-step example, see [Get started with ext4 images](getting-started.md).

## Toolchain types

Each rule uses one toolchain type:

| Rule | Toolchain type | Value of the `type` attribute |
|---|---|---|
| `ext4` | `@score_rules_imagefs//toolchains/linux:ext4_toolchain_type` | `ext4` |
| `qnx_ifs` | `@score_rules_imagefs//toolchains/qnx:ifs_toolchain_type` | `ifs` |
| `qnx6fs` | `@score_rules_imagefs//toolchains/qnx:qnx6fs_toolchain_type` | `qnx6fs` |
| `fatfs` | `@score_rules_imagefs//toolchains/qnx:fatfs_toolchain_type` | `fatfs` |
| `diskimage` | `@score_rules_imagefs//toolchains/qnx:diskimage_toolchain_type` | `diskimage` |

## Add the module

1. Add the S-CORE registry and the Bazel Central Registry to your `.bazelrc`:

   ```text
   common --registry=https://raw.githubusercontent.com/eclipse-score/bazel_registry/main/
   common --registry=https://bcr.bazel.build
   ```

1. Add the dependency to your `MODULE.bazel`:

   ```starlark
   bazel_dep(name = "score_rules_imagefs", version = "VERSION")
   ```

   Replace `VERSION` with the release that you want to use.

1. Load the extension:

   ```starlark
   imagefs = use_extension("@score_rules_imagefs//extensions:imagefs.bzl", "imagefs")
   ```

Only the root module of a build can use the `imagefs` extension. If a
dependency of your module uses it, the build fails with
`Only the root module can use the 'imagefs' extension!`.

## Declare an ext4 toolchain

The `ext4` toolchain needs no SDP. The extension provides both tools:

- `coreutils`: a prebuilt multicall binary (uutils) that
  [bazel_lib](https://github.com/bazel-contrib/bazel-lib) downloads. The rule
  calls its `du`, `cp`, `mkdir`, `ln`, and `truncate` subcommands.
- `mke2fs`: built from e2fsprogs 1.47.4 source. The extension downloads the
  source and Bazel compiles it. The host `PATH` isn't used.

To declare and register the toolchain:

1. Add a `toolchain` tag to your `MODULE.bazel`:

   ```starlark
   imagefs.toolchain(
       name = "ext4_toolchain_linux_x86_64",
       target_cpu = "x86_64",
       target_os = "linux",
       type = "ext4",
   )
   use_repo(imagefs, "ext4_toolchain_linux_x86_64")
   ```

1. Register the toolchain target that the extension generates. Its name is
   `ext4-CPU-OS`, where `CPU` and `OS` are the values of `target_cpu` and
   `target_os`:

   ```starlark
   register_toolchains("@ext4_toolchain_linux_x86_64//:ext4-x86_64-linux")
   ```

If several `toolchain` tags use `type = "ext4"`, the extension fetches and
builds e2fsprogs once and shares it.

The generated toolchain can run only on x86_64 Linux hosts, because the
bundled `coreutils` binary is the `linux_amd64` build and the toolchain's
`exec_compatible_with` is x86_64 Linux. The `target_cpu` and `target_os` values
must match the target platform of the image. The extension accepts `x86_64`
and `aarch64` for the CPU.

To register the toolchain only for a specific build configuration instead of
for every build, put the following line in your `.bazelrc` and build with
`--config=x86_64-linux-ext4`. The [tests](../tests/.bazelrc) in this repository
use this approach.

```text
build:x86_64-linux-ext4 --extra_toolchains=@ext4_toolchain_linux_x86_64//:ext4-x86_64-linux
```

## Declare a QNX toolchain

QNX toolchains need a QNX Software Development Platform (SDP). You can either
let the extension download the SDP, or reuse an SDP that another extension
already defines, for example the one used by your C++ toolchain.

To declare and register a QNX toolchain with an SDP that the extension
downloads:

1. Add an `sdp` tag that describes the SDP archive, then a `toolchain` tag that
   points to it with `sdp_to_import`:

   ```starlark
   imagefs.sdp(
       name = "qnx_sdp_pkg",
       url = "SDP_URL",
       sha256 = "SDP_SHA256",
       strip_prefix = "SDP_ARCHIVE_ROOT",
       build_file = "//toolchains:qnx_sdp.BUILD",
   )
   imagefs.toolchain(
       name = "qnx_ifs_toolchain_x86_64",
       sdp_to_import = "@qnx_sdp_pkg",
       sdp_version = "8.0.0",
       target_cpu = "x86_64",
       target_os = "qnx",
       type = "ifs",
   )
   use_repo(imagefs, "qnx_ifs_toolchain_x86_64", "qnx_sdp_pkg")
   ```

   Replace the placeholders:

   - `SDP_URL`: the URL of the SDP archive.
   - `SDP_SHA256`: the SHA-256 checksum of the archive.
   - `SDP_ARCHIVE_ROOT`: the top-level directory to strip from the archive.

1. Register the generated toolchain. Its name is
   `TYPE-CPU-qnx-sdp_SDP_VERSION`:

   ```starlark
   register_toolchains("@qnx_ifs_toolchain_x86_64//:ifs-x86_64-qnx-sdp_8.0.0")
   ```

To reuse an SDP from another extension, skip the `sdp` tag and set
`sdp_to_import` to the label of that SDP repository, for example
`sdp_to_import = "@my_sdp"`.

The S-CORE [reference_integration](https://github.com/eclipse-score/reference_integration)
repository uses `sdp_to_import` with the SDP of its C++ toolchain, and
registers the generated toolchains with `--extra_toolchains` in `.bazelrc`. See
[Example configuration](qnx-images.md#example-configuration).

Each `toolchain` tag defines one image type. To build several QNX image types,
add one `toolchain` tag for each type, then register each generated target.

The SDP repository must provide the following targets, because the generated
toolchain refers to them:

| Target | Purpose |
|---|---|
| `mkTYPE` | The executable for the image type, for example `mkifs` for `type = "ifs"` or `mkqnx6fs` for `type = "qnx6fs"`. |
| `host_dir` | A single file or directory that represents the SDP host directory (`QNX_HOST`). |
| `target_dir` | A single file or directory that represents the SDP target directory (`QNX_TARGET`). |
| `host_all` | All host files that the tool needs at run time. |
| `target_all` | All target files that the tool needs at run time. |

The generated QNX toolchain targets are compatible with the constraint
`@score_bazel_platforms//version:sdp_SDP_VERSION`. Your target platform must
include that constraint, for example `sdp_8.0.0`.

For the environment that the toolchain sets, see
[Build QNX images](qnx-images.md#environment-variables).

## Define an ext4 toolchain yourself

If you want to supply your own `mke2fs` and `coreutils`, for example to use
prebuilt binaries that your company controls, define the toolchain directly
instead of using the extension.

1. Declare the toolchain in a `BUILD` file:

   ```starlark
   load("@score_rules_imagefs//toolchains/linux:toolchains.bzl", "ext4_toolchain_config")

   ext4_toolchain_config(
       name = "ext4_toolchain",
       coreutils = "@my_coreutils//:coreutils",
       mke2fs = "@my_e2fsprogs//:mke2fs",
   )

   toolchain(
       name = "ext4_toolchain_def",
       exec_compatible_with = ["@platforms//os:linux"],
       toolchain = ":ext4_toolchain",
       toolchain_type = "@score_rules_imagefs//toolchains/linux:ext4_toolchain_type",
   )
   ```

1. Register the toolchain in your `MODULE.bazel`:

   ```starlark
   register_toolchains("//path/to:ext4_toolchain_def")
   ```

The attributes of `ext4_toolchain_config` are:

| Attribute | Type | Description |
|---|---|---|
| `mke2fs` | Label (executable, mandatory) | The `mke2fs` tool. |
| `coreutils` | Label (single file, mandatory) | A file that the rule calls as `coreutils SUBCOMMAND ARGS...` for `du`, `cp`, `mkdir`, `ln`, and `truncate`. Use a multicall binary, or a small script that dispatches to host tools. |

The `du` subcommand must support the `-b` and `-s` options, because the rule
uses `du -sb` to measure the content size.

## Reference: tag attributes

### The `toolchain` tag

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | String (mandatory) | – | Name of the generated repository. |
| `type` | String (mandatory) | – | Image type: `ifs`, `qnx6fs`, `fatfs`, `diskimage`, or `ext4`. |
| `target_cpu` | String (mandatory) | – | Target CPU: `x86_64` or `aarch64`. |
| `target_os` | String (mandatory) | – | Target OS: `linux` or `qnx`. Use `linux` for `ext4` and `qnx` for the other types. |
| `sdp_to_import` | Label | None | The SDP repository to use. Required for QNX types. Not used for `ext4`. |
| `sdp_version` | String | `8.0.0` | Label of the `sdp_VERSION` platform constraint that the toolchain requires. It need not equal the SDP archive version. Not used for `ext4`. |
| `license_path`, `license_info_url`, `license_info_variable` | String | `/opt/score_qnx/license/licenses` for `license_path`; empty for the others | The toolchain ignores these attributes. |

The toolchain ignores the three license attributes. QNX tools use the fixed
license settings that [Build QNX images](qnx-images.md#environment-variables)
lists.

### The `sdp` tag

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | String | Empty | Name of the repository that holds the unpacked SDP. |
| `url` | String | Empty | URL of the SDP archive. |
| `sha256` | String | Empty | SHA-256 checksum of the archive. |
| `strip_prefix` | String | Empty | Directory prefix to strip from the archive. |
| `build_file` | Label | None | `BUILD` file to place in the SDP repository. It defines the targets in the table above. |

## Licensing

The `ext4` toolchain compiles `mke2fs` from e2fsprogs 1.47.4 source. That
source is licensed under GPL-2.0-only, LGPL-2.0-only, BSD-3-Clause, and MIT.
Those terms are separate from the Apache License 2.0 of this repository. The
module uses `mke2fs` only as a build tool, and doesn't link it into your
images. Before you redistribute a built `mke2fs` binary, read the
"Third-party Content" section of the [NOTICE](../NOTICE) file.
