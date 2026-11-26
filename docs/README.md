<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# rules_imagefs documentation

`score_rules_imagefs` is a Bazel module that builds filesystem and boot images
as part of a Bazel build. It provides rules for ext4 images (Linux) and for
QNX IFS, QNX6, FAT, and disk images.

This documentation is for engineers who write Bazel builds for embedded Linux
or QNX targets and who already know basic Bazel concepts such as targets,
`MODULE.bazel`, and toolchains. It doesn't teach Bazel itself.

## Choose a page

| I want to… | Read |
|---|---|
| Build my first ext4 image in about 10 minutes | [Get started with ext4 images](getting-started.md) |
| Set up or change the toolchain for an image type | [Configure toolchains](toolchains.md) |
| Build QNX IFS, QNX6, FAT, or disk images | [Build QNX images](qnx-images.md) |
| Look up a rule, an attribute, or a tag | [Rule reference](rules.md) |
| Understand how the module fits together | [How it works](how-it-works.md) |
| Fix an error message | [Troubleshooting](troubleshooting.md) |
| Change this repository or run its tests | [Development guide](development.md) |

## Supported image types

| Rule | Image type | Output file | Host tool |
|---|---|---|---|
| `ext4` | ext4 filesystem without a journal | `NAME.ext4` | Built from source by the module. No QNX SDP needed. |
| `qnx_ifs` | QNX Image Filesystem | `NAME.ifs` | `mkifs` from a QNX SDP |
| `qnx6fs` | QNX6 filesystem | `NAME.img` | `mkqnx6fs` from a QNX SDP |
| `fatfs` | FAT filesystem | `NAME.img` | `mkfatfs` from a QNX SDP |
| `diskimage` | Composite disk image | `NAME.img` | `mkdiskimage` from a QNX SDP |

In the *Output file* column, `NAME` is the `name` attribute of the target.
You can override the file name with the `out` attribute.

The tool names in the last column are the SDP targets that the generated
toolchain looks up. See [Configure toolchains](toolchains.md) for details.

## License

The module is licensed under the Apache License 2.0. The ext4 toolchain builds
`mke2fs` from e2fsprogs source, which has different license terms. See
[Licensing](toolchains.md#licensing) and the [NOTICE](../NOTICE) file.
