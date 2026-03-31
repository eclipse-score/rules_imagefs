# rules_imagefs

Bazel rules and toolchain setup for generating QNX image and filesystem artifacts.

This repository provides Starlark rules for building several QNX image types:

- `qnx_ifs` for QNX IFS images
- `qnx6fs` for QNX6 filesystem images
- `fatfs` for FAT filesystem images
- `diskimage` for composite disk images

It also provides a Bazel module extension for registering the corresponding QNX toolchains from an SDP archive.

## Repository layout

```text
rules_imagefs/
├── extensions/
│   └── imagefs.bzl
├── rules/qnx/
│   ├── diskimage.bzl
│   ├── fatfs.bzl
│   ├── ifs.bzl
│   ├── imagefs_toolchain.bzl
│   └── qnx6fs.bzl
├── templates/qnx/
├── toolchains/qnx/
│   └── toolchains.bzl
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

## Rule loading

```starlark
load("@score_rules_imagefs//rules/qnx:ifs.bzl", "qnx_ifs")
load("@score_rules_imagefs//rules/qnx:qnx6fs.bzl", "qnx6fs")
load("@score_rules_imagefs//rules/qnx:fatfs.bzl", "fatfs")
load("@score_rules_imagefs//rules/qnx:diskimage.bzl", "diskimage")
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
