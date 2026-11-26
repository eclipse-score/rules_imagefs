<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# rules_imagefs

`score_rules_imagefs` is a Bazel module that builds filesystem and boot images
from `rules_pkg` targets:

| Rule | Image type |
|---|---|
| `ext4` | ext4 filesystem without a journal. Builds on x86_64 Linux hosts and needs no QNX software. |
| `qnx_ifs` | QNX Image Filesystem |
| `qnx6fs` | QNX6 filesystem |
| `fatfs` | FAT filesystem |
| `diskimage` | Composite disk image |

The QNX rules need a QNX Software Development Platform (SDP). A module
extension, `imagefs`, creates and configures the toolchains for all rules.

## Quick start

Add the module and an ext4 toolchain to your `MODULE.bazel`. Replace `VERSION`
with the release that you want to use:

```starlark
bazel_dep(name = "rules_pkg", version = "1.2.0")
bazel_dep(name = "score_rules_imagefs", version = "VERSION")

imagefs = use_extension("@score_rules_imagefs//extensions:imagefs.bzl", "imagefs")
imagefs.toolchain(
    name = "ext4_toolchain_linux_x86_64",
    target_cpu = "x86_64",
    target_os = "linux",
    type = "ext4",
)
use_repo(imagefs, "ext4_toolchain_linux_x86_64")

register_toolchains("@ext4_toolchain_linux_x86_64//:ext4-x86_64-linux")
```

Add the S-CORE and Bazel Central registries to your `.bazelrc`:

```text
common --registry=https://raw.githubusercontent.com/eclipse-score/bazel_registry/main/
common --registry=https://bcr.bazel.build
```

Then declare an image in a `BUILD` file:

```starlark
load("@rules_pkg//pkg:mappings.bzl", "pkg_files")
load("@score_rules_imagefs//rules/linux:ext4.bzl", "ext4")

pkg_files(
    name = "rootfs_files",
    srcs = ["hello.txt"],
    prefix = "etc",
)

ext4(
    name = "rootfs_ext4",
    srcs = [":rootfs_files"],
)
```

Build it with `bazel build //:rootfs_ext4`. The image is
`bazel-bin/rootfs_ext4.ext4`.

## Documentation

The [docs](docs/README.md) directory has the full documentation:

- [Get started with ext4 images](docs/getting-started.md): a tutorial that
  builds and checks your first image.
- [Configure toolchains](docs/toolchains.md): declare toolchains for ext4 and
  QNX images, or define an ext4 toolchain yourself.
- [Build QNX images](docs/qnx-images.md): build IFS, QNX6, FAT, and disk images.
- [Rule reference](docs/rules.md): every rule and attribute.
- [How it works](docs/how-it-works.md): the structure of the module.
- [Troubleshooting](docs/troubleshooting.md): causes and fixes for common errors.
- [Development guide](docs/development.md): tests, formatting, and release
  checks for contributors.

## License

The module is licensed under the Apache License 2.0. See [LICENSE](LICENSE).

The `ext4` toolchain builds `mke2fs` from e2fsprogs source, which has different
license terms. See [NOTICE](NOTICE) for details before you redistribute a built
`mke2fs` binary.
