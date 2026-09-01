# rules_imagefs

Bazel rules and toolchain setup for generating QNX image and filesystem artifacts.

This repository provides Starlark rules for building several QNX image types:

- `qnx_ifs` for QNX IFS images
- `qnx6fs` for QNX6 filesystem images
- `fatfs` for FAT filesystem images
- `diskimage` for composite disk images
- `ext4` for Linux ext4 filesystem images without journaling

It also provides a Bazel module extension for registering the corresponding QNX toolchains from an SDP archive.

## Repository layout

```text
rules_imagefs/
├── extensions/
│   └── imagefs.bzl
├── rules/
│   ├── imagefs_toolchain.bzl
│   ├── linux/
│   │   ├── ext4.bzl
│   │   └── tools/
│   └── qnx/
│       ├── common/
│       ├── diskimage.bzl
│       ├── fatfs.bzl
│       ├── ifs.bzl
│       └── qnx6fs.bzl
├── templates/
│   ├── linux/
│   └── qnx/
├── toolchains/
│   ├── linux/
│   │   ├── toolchains.bzl
│   │   └── tools/
│   └── qnx/
│       └── toolchains.bzl
├── tests/                 # nested Bazel module exercising this repo as a consumer
├── MODULE.bazel
└── README.md
```

## Features

### `qnx_ifs`
Builds a QNX Image Filesystem image using the QNX IFS toolchain.

The rule accepts a main build file and optional supporting inputs. It also supports `search_roots`, which are passed as `-r` arguments to the underlying tool.

### `qnx6fs`
Builds a QNX6 filesystem image from the provided build file and inputs.

### `fatfs`
Builds a FAT filesystem image using the QNX `mkfatfsimg` flow.

### `diskimage`
Builds a composite disk image from a main disk layout build file. The rule supports a `gpt_enabled` boolean attribute that passes `-g` to the underlying QNX `diskimage` tool.

### `ext4`
Builds an ext4 filesystem image from the provided `srcs` files without a journal.

The rule invokes `mke2fs` through the `//toolchains/linux:ext4_toolchain_type` toolchain. No toolchain of this type is registered by default, so a `type = "ext4"` toolchain must be configured before the rule can build (see below). The `imagefs` module extension's `ext4` toolchain provisions a hermetic `coreutils` automatically (prebuilt uutils binaries via `bazel_lib`, used for `du`, `cp`, `mkdir`, `ln`, `truncate`), but currently still shells out to whatever `mke2fs` is on the exec host's `PATH` — `sdp_to_import`/`sdp` are not yet wired up to supply `mke2fs` (an accepted interim limitation). To fully control both tools yourself, register a toolchain directly via `ext4_toolchain_config` instead (see below).

## Module usage

Add the dependency in your `MODULE.bazel` (replace the version string with the release you want to use):

```starlark
bazel_dep(name = "score_rules_imagefs", version = "<release version>")  # e.g., "0.0.2"
```

Then import the module extension:

```starlark
imagefs = use_extension("@score_rules_imagefs//extensions:imagefs.bzl", "imagefs")
```

## Toolchain configuration

The module extension defines two tag classes:

- `sdp`: declares the QNX SDP archive to fetch
- `toolchain`: declares an image-generation toolchain instance

### `sdp` tag

Use `sdp` to describe the archive that contains the QNX host/target toolchain payload.

```starlark
imagefs.sdp(
    name = "qnx_sdp_pkg",
    url = "https://example.invalid/qnx-sdp.tar.gz",
    sha256 = "<sha256>",
    strip_prefix = "<archive-root>",
    build_file = "//toolchains:qnx_sdp.BUILD",
)
```

### `toolchain` tag

Use `toolchain` to define a concrete toolchain instance for one image type.

```starlark
imagefs.toolchain(
    name = "qnx_ifs_toolchain_linux_x86_64",
    target_cpu = "x86_64",
    target_os = "qnx",
    sdp_version = "8.0.0",
    type = "ifs",
)
```
Since the tooling for creating image filesystems sometimes comes bundled with the C/C++ toolchain binaries, the `toolchain` tag also supports reusing an already defined SDP (for example, when the C/C++ build uses the same SDP). To include an already defined SDP in the project, use the dedicated `sdp_to_import` field:

```starlark
imagefs.toolchain(
    name = "qnx_ifs_toolchain_linux_x86_64",
    target_cpu = "x86_64",
    sdp_to_import = "@my_sdp",
    target_os = "qnx",
    sdp_version = "8.0.0",
    type = "ifs",
)
```

Supported `type` values:
- `ifs`
- `qnx6fs`
- `fatfs`
- `diskimage`
- `ext4`

For `ext4`, no `sdp`/`sdp_to_import` is needed — the extension provisions a hermetic `coreutils` for you and wires `mke2fs` to the exec host's `PATH` (see [`ext4`](#ext4) above):

```starlark
imagefs.toolchain(
    name = "ext4_toolchain_linux_x86_64",
    target_cpu = "x86_64",
    target_os = "linux",
    type = "ext4",
)
```

Then register the generated toolchain in your `MODULE.bazel`:

```starlark
use_repo(imagefs, "ext4_toolchain_linux_x86_64")

register_toolchains("@ext4_toolchain_linux_x86_64//:ext4-x86_64-linux")
```

## Rule loading

```starlark
load("@score_rules_imagefs//rules/qnx:ifs.bzl", "qnx_ifs")
load("@score_rules_imagefs//rules/qnx:qnx6fs.bzl", "qnx6fs")
load("@score_rules_imagefs//rules/qnx:fatfs.bzl", "fatfs")
load("@score_rules_imagefs//rules/qnx:diskimage.bzl", "diskimage")
load("@score_rules_imagefs//rules/linux:ext4.bzl", "ext4")
```

## Basic rule examples

### QNX IFS

```starlark
qnx_ifs(
    name = "system_ifs",
    build_file = ":image.build",
    srcs = [
        ":files",
    ],
    search_roots = [
        "rootfs",
    ],
)
```

### QNX6 filesystem

```starlark
qnx6fs(
    name = "system_qnx6fs",
    build_file = ":fs.build",
    srcs = [
        ":rootfs_files",
    ],
)
```

### FAT filesystem

```starlark
fatfs(
    name = "boot_fatfs",
    build_file = ":fat.build",
    srcs = [
        ":boot_files",
    ],
)
```

### Disk image

```starlark
diskimage(
    name = "target_disk",
    build_file = ":disk.build",
    srcs = [
        ":partition_boot",
        ":partition_rootfs",
    ],
    gpt_enabled = True,
)
```

### ext4 filesystem

```starlark
ext4(
    name = "rootfs_ext4",
    srcs = [":rootfs_files"],
)
```

A toolchain of this type must be registered before this rule can build — either via the `imagefs` module extension's `type = "ext4"` tag (see [Toolchain configuration](#toolchain-configuration) above, which generates the boilerplate below for you), or directly, e.g. to supply fully hermetic `mke2fs`/`coreutils` executables of your own:

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

Then register it in your `MODULE.bazel`:

```starlark
register_toolchains("//path/to:ext4_toolchain_def")
```

## Environment and licensing

The QNX image toolchain config sets up runtime environment variables for the underlying tools, including:

- `QNX_HOST`
- `QNX_TARGET`
- `PATH`

## Development

- `//:format.fix`
- `//:format.check`
- `//:copyright`

## License

Apache License 2.0
