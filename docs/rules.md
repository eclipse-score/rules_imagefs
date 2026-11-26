<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# Rule reference

This page describes every rule that `score_rules_imagefs` provides, with its
attributes and behavior. For task-oriented guidance, see
[Get started with ext4 images](getting-started.md) and
[Build QNX images](qnx-images.md).

## Load the rules

```starlark
load("@score_rules_imagefs//rules/linux:ext4.bzl", "ext4")
load("@score_rules_imagefs//rules/qnx:ifs.bzl", "qnx_ifs")
load("@score_rules_imagefs//rules/qnx:qnx6fs.bzl", "qnx6fs")
load("@score_rules_imagefs//rules/qnx:fatfs.bzl", "fatfs")
load("@score_rules_imagefs//rules/qnx:diskimage.bzl", "diskimage")
```

## Behavior shared by all rules

### The `srcs` attribute

The `srcs` attribute lists targets that provide image content. Each target must
provide at least one of the [rules_pkg](https://github.com/bazelbuild/rules_pkg)
providers `PackageFilesInfo`, `PackageDirsInfo`, `PackageSymlinkInfo`, or
`PackageFilegroupInfo`. The rules `pkg_files`, `pkg_mkdirs`, `pkg_mklink`, and
`pkg_filegroup` produce these providers. A target without such a provider
makes the build fail. To add another kind of file, such as a generated image,
wrap it in `pkg_files`.

The destination of each file in the image is the destination that the
`rules_pkg` target defines. For example, `pkg_files` with `prefix = "etc"` and
`srcs = ["hello.txt"]` places the file at `/etc/hello.txt`.

### The `out` attribute

The `out` attribute sets the name of the output file. The value must be a file
name without a directory part. If you leave it empty, the rule derives the
name from the target name and the image type:

| Rule | Default output file |
|---|---|
| `ext4` | `NAME.ext4` |
| `qnx_ifs` | `NAME.ifs` |
| `qnx6fs`, `fatfs`, `diskimage` | `NAME.img` |

In the table, `NAME` is the target name. A value that contains `/` makes the
build fail with `Output file must be a filename without path components`.

### Providers

Every rule returns only `DefaultInfo`. Its `files` contain the image.

## ext4

Builds an ext4 filesystem image without a journal. The rule runs only on
Linux execution platforms and needs a toolchain of type
`@score_rules_imagefs//toolchains/linux:ext4_toolchain_type`. See
[Configure toolchains](toolchains.md#declare-an-ext4-toolchain).

```starlark
ext4(
    name = "rootfs_ext4",
    srcs = [":rootfs_files"],
)
```

### Attributes

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | Name (mandatory) | – | Target name. |
| `srcs` | List of labels (mandatory) | – | `rules_pkg` targets that provide files, directories, and symbolic links. |
| `out` | String | `NAME.ext4` | Output file name, without a directory part. |

### Behavior

The rule runs one action for each image. The action:

1. Copies the content of `srcs` into a temporary staging directory. Directories
   are created, files are copied (a directory artifact is copied recursively
   and symbolic links in it are followed), and symbolic links are created.
1. Measures the staged content and sets the image size to the content size
   plus 10 percent plus 16 MiB, rounded up to a multiple of 4096 bytes.
1. Creates a sparse file of that size and formats it with
   `mke2fs -q -t ext4 -O ^has_journal -d STAGING_DIRECTORY`.

The size isn't configurable. The image has no journal.

The rule ignores the `mode`, `uid`, and `gid` values that `pkg_attributes` can
set on `rules_pkg` targets. File ownership and permissions in the image come
from the staged files. Ownership typically matches the user and group IDs of
the user who runs the build.

## qnx_ifs

Builds a QNX Image Filesystem (IFS) image with `mkifs`. Needs a toolchain of
type `@score_rules_imagefs//toolchains/qnx:ifs_toolchain_type`.

```starlark
qnx_ifs(
    name = "system_ifs",
    build_file = ":image.build",
    srcs = [":files"],
    search_roots = ["rootfs"],
)
```

### Attributes

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | Name (mandatory) | – | Target name. |
| `build_file` | Label (mandatory) | – | The main QNX build file. It must resolve to a single file. |
| `srcs` | List of labels (mandatory) | – | `rules_pkg` targets that provide image content. |
| `extra_build_files` | List of labels | `[]` | More build files, included after `build_file` in the order that you list them. |
| `search_roots` | List of strings | `[]` | Paths that the rule passes to `mkifs` as `-r` options. Paths are relative to the directory of the main build file, or absolute. |
| `search_srcs` | List of labels | `[]` | Files that the rule makes available to the action but doesn't add as image content. Use them for files that a build file refers to by bare name, so `mkifs` can find them through `search_roots` or `[search=...]`. |
| `out` | String | `NAME.ifs` | Output file name, without a directory part. |

## qnx6fs

Builds a QNX6 filesystem image. Needs a toolchain of type
`@score_rules_imagefs//toolchains/qnx:qnx6fs_toolchain_type`.

```starlark
qnx6fs(
    name = "system_qnx6fs",
    build_file = ":fs.build",
    srcs = [":rootfs_files"],
)
```

### Attributes

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | Name (mandatory) | – | Target name. |
| `build_file` | Label (mandatory) | – | The main QNX build file. It must resolve to a single file. |
| `srcs` | List of labels (mandatory) | – | `rules_pkg` targets that provide image content. |
| `extra_build_files` | List of labels | `[]` | More build files, included after `build_file`. |
| `out` | String | `NAME.img` | Output file name, without a directory part. |

## fatfs

Builds a FAT filesystem image. Needs a toolchain of type
`@score_rules_imagefs//toolchains/qnx:fatfs_toolchain_type`. The attributes are
the same as for [`qnx6fs`](#qnx6fs), and the default output file is
`NAME.img`.

```starlark
fatfs(
    name = "boot_fatfs",
    build_file = ":fat.build",
    srcs = [":boot_files"],
)
```

## diskimage

Builds a composite disk image with the QNX `diskimage` tool. Needs a toolchain
of type `@score_rules_imagefs//toolchains/qnx:diskimage_toolchain_type`.

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

### Attributes

| Attribute | Type | Default | Description |
|---|---|---|---|
| `name` | Name (mandatory) | – | Target name. |
| `build_file` | Label (mandatory) | – | The disk layout file. It must resolve to a single file. |
| `srcs` | List of labels (mandatory) | – | `rules_pkg` targets whose files, for example partition images, the layout file refers to. The rule makes these files available to the action. |
| `extra_build_files` | List of labels | `[]` | More layout files. The rule appends them to `build_file`, in the order that you list them. |
| `gpt_enabled` | Boolean | `False` | If true, passes `-g` to `diskimage` to create a GUID Partition Table (GPT) disk image. If false, the rule doesn't pass `-g`. |
| `out` | String | `NAME.img` | Output file name, without a directory part. |

### Behavior

The `diskimage` tool reads a disk layout file only. It doesn't understand the
`[+include]` directive that the other QNX rules use. So the rule concatenates
`build_file` and `extra_build_files` into one file, and passes that file to
`diskimage -o OUTPUT -c FILE`. The rule doesn't generate file entries from
`srcs` for this image type.

## How the QNX rules assemble the build file

The `qnx_ifs`, `qnx6fs`, and `fatfs` rules write a main build file that
includes, in this order:

1. `build_file`
1. Each file in `extra_build_files`
1. A generated file, `NAME_pkg_content.build`, with one entry for each
   directory, file, and symbolic link in `srcs`

The generated entries use these defaults. A `pkg_attributes` value on the
`rules_pkg` target overrides the default for `mode`, `uid`, and `gid`:

| Entry type | Mode | User ID | Group ID |
|---|---|---|---|
| Directory | `0755` | 0 | 0 |
| File | `0644` | 0 | 0 |
| Symbolic link | `0777` | 0 | 0 |

The generated file also sets `mtime` to the fixed value `2021-03-22-20:20:00`,
so the same inputs produce the same image.
