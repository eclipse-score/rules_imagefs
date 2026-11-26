<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

<!-- TODO(verify): The IFS flow is covered by the automated test in
tests/qnx/ifs and checked against eclipse-score/reference_integration. The
qnx6fs, fatfs, and diskimage sections, and the `sdp` tag, have no automated
test and no known real-world usage. Run them with a real SDP before you publish
those parts. -->

# Build QNX images

This page shows how to build QNX IFS, QNX6, FAT, and disk images. It is for
engineers who already have a QNX Software Development Platform (SDP) and know
the QNX build file syntax. For the syntax, see the documentation that comes
with your SDP.

## Before you begin

- Install the host tools that your QNX SDP needs, and make sure that your QNX
  license is available. See [Environment variables](#environment-variables).
- Declare and register a toolchain for each image type that you build. See
  [Declare a QNX toolchain](toolchains.md#declare-a-qnx-toolchain).
- Build for a platform that includes the SDP version constraint, for example
  `@score_bazel_platforms//:x86_64-qnx-sdp_8.0.0-posix`.
- Allow the action sandbox to write to `/var/tmp`, because the toolchain sets
  `QNX_CONFIGURATION_EXCLUSIVE` to `/var/tmp/.qnx`. Add
  `build --sandbox_writable_path=/var/tmp` to your `.bazelrc`.

## Example configuration

The [reference_integration](https://github.com/eclipse-score/reference_integration)
repository builds QNX IFS images for x86_64 and aarch64 with this module. Its
setup has these parts:

- The `MODULE.bazel` files declare one `ifs` toolchain for each CPU. Both reuse
  the SDP that the C++ toolchain defines (`sdp_to_import`):

  ```starlark
  imagefs = use_extension("@score_rules_imagefs//extensions:imagefs.bzl", "imagefs", dev_dependency = True)
  imagefs.toolchain(
      name = "score_qnx_x86_64_ifs_toolchain",
      sdp_to_import = "@qnx_sdp_8_0_5_pkg",
      sdp_version = "8.0.0",
      target_cpu = "x86_64",
      target_os = "qnx",
      type = "ifs",
  )
  use_repo(imagefs, "score_qnx_x86_64_ifs_toolchain")
  ```

  The `sdp_version` value selects the `sdp_8.0.0` platform constraint. It
  doesn't have to equal the version of the SDP archive, which is 8.0.5 here.

- The `.bazelrc` file registers the toolchain for a build configuration, and
  sets the platform that carries the matching constraint:

  ```text
  build:qnx-x86_64 --platforms=@score_bazel_platforms//:x86_64-qnx-sdp_8.0.0-posix
  build:qnx-x86_64 --extra_toolchains=@score_qnx_x86_64_ifs_toolchain//:ifs-x86_64-qnx-sdp_8.0.0
  build:qnx-x86_64 --sandbox_writable_path=/var/tmp
  ```

  You then build with `bazel build --config=qnx-x86_64 TARGET`.

- The image target combines `pkg_files` targets with shared build file
  fragments. It sets file modes with `pkg_attributes`, and it places files that
  must be in the boot image under `proc/boot`:

  ```starlark
  pkg_files(
      name = "pci_configs",
      srcs = ["pci_hw.cfg", "pci_server.cfg"],
      attributes = pkg_attributes(mode = "0444"),
      prefix = "proc/boot",
      strip_prefix = strip_prefix.files_only(),
  )

  qnx_ifs(
      name = "init",
      srcs = [":pci_configs", "//images/qnx_common/configs:etc_configs"],
      build_file = "init.build",
      extra_build_files = [
          "//images/qnx_common/build:common_init.build",
          "system.build",
      ],
  )
  ```

  The architecture-specific `init.build` holds the `[virtual=...]` boot block.
  The fragments in `extra_build_files` hold what the architectures share.

## Build an IFS image

1. Create a `pkg_files` target for the files that go into the image:

   ```starlark
   load("@rules_pkg//pkg:mappings.bzl", "pkg_files")

   pkg_files(
       name = "files",
       srcs = ["my_app"],
       prefix = "usr/bin",
   )
   ```

1. Create the QNX build file, for example `image.build`, that describes the
   boot image.

1. Add a `qnx_ifs` target:

   ```starlark
   load("@score_rules_imagefs//rules/qnx:ifs.bzl", "qnx_ifs")

   qnx_ifs(
       name = "system_ifs",
       build_file = ":image.build",
       srcs = [":files"],
       search_roots = ["rootfs"],
   )
   ```

   The `search_roots` attribute adds `-r rootfs` to the `mkifs` command line.
   If your build file refers to a file by its bare name, add that file to
   `search_srcs` so that Bazel makes it available to `mkifs` without placing it
   in the image.

1. Build the target:

   ```shell
   bazel build //:system_ifs
   ```

   The image is `bazel-bin/system_ifs.ifs`.

## Boot an IFS image in QEMU

You can boot an x86_64 IFS image in QEMU to check it without hardware. The
[IFS test](../tests/qnx/ifs) in this repository does this: it builds an image
with a C program that prints a message, boots the image, and waits for the
message on the serial console. This section shows how to do the same for your
image.

### Before you begin

- Install `qemu-system-x86_64`.
- Build an x86_64 IFS image, as described in
  [Build an IFS image](#build-an-ifs-image).

### Prepare the image

1. In the boot file, start the serial driver and redirect the console to it
   before you run your program. The following startup script is the one that the
   test uses:

   ```text
   [+script] startup-script = {
       procmgr_symlink /dev/shmem /tmp
       SYSNAME=nto
       TERM=qansi

       devc-ser8250 &
       waitfor /dev/ser1
       reopen /dev/ser1

       hello
   }
   ```

   The boot block starts the kernel with `startup-x86 -D8250..115200 -zz`. The
   `-D8250..115200` option sends the kernel's debug output to the 8250 serial
   port at 115200 baud.

1. Place your program in `/proc/boot`, which is in the `PATH` that the boot file
   sets, and make it executable:

   ```starlark
   pkg_files(
       name = "hello_files",
       srcs = [":hello"],
       attributes = pkg_attributes(mode = "0755"),
       prefix = "proc/boot",
   )
   ```

1. Add every shared library that your program and the serial driver need to the
   boot file. To list the libraries of a binary, run `readelf -d` on it and
   read the `NEEDED` lines. The test image contains these libraries:

   ```text
   libc.so.6
   libgcc_s.so.1
   libm.so.3
   libc++.so.2
   libsecpol.so.1
   /usr/lib/ldqnx-64.so.2=ldqnx-64.so.2
   ```

   In the test, the C program is linked against `libc++`, and `devc-ser8250`
   needs `libsecpol`. If a library is missing, the
   serial console shows `ldd:FATAL: Could not load library NAME`.

### Boot the image

1. Run QEMU with the image as the kernel and the serial port written to a file:

   ```shell
   qemu-system-x86_64 -cpu Cascadelake-Server-v5 -m 256M -smp 2 \
       -display none -monitor none -no-reboot \
       -serial file:serial.log -kernel bazel-bin/system_ifs.ifs
   ```

   If `/dev/kvm` is writable, add `-enable-kvm` to start faster. Always set a
   named CPU model. QNX 8.0 crashes early in boot with `-cpu host`, and the
   serial log ends with `WARNING: Too early for per-cpu data` and a register
   dump.

1. In a second terminal, confirm that the log contains the message of your
   program:

   ```shell
   grep "hello from qnx ifs" serial.log
   ```

1. Stop QEMU with `Ctrl+C`.

## Build a QNX6 or FAT filesystem image

The `qnx6fs` and `fatfs` rules take the same attributes. Use `qnx6fs` for a
QNX6 filesystem and `fatfs` for a FAT filesystem:

```starlark
load("@score_rules_imagefs//rules/qnx:fatfs.bzl", "fatfs")
load("@score_rules_imagefs//rules/qnx:qnx6fs.bzl", "qnx6fs")

qnx6fs(
    name = "system_qnx6fs",
    build_file = ":fs.build",
    srcs = [":rootfs_files"],
)

fatfs(
    name = "boot_fatfs",
    build_file = ":fat.build",
    srcs = [":boot_files"],
)
```

The images are `bazel-bin/system_qnx6fs.img` and `bazel-bin/boot_fatfs.img`.

## Build a disk image from partition images

The `diskimage` rule builds a disk from a layout file. The layout file
refers to partition images, for example the output of a `qnx6fs` or `fatfs`
target.

The `srcs` attribute accepts only targets that provide `rules_pkg` providers.
To use a generated image as a partition, wrap it in `pkg_files`:

1. Wrap the partition images:

   ```starlark
   pkg_files(
       name = "partition_boot",
       srcs = [":boot_fatfs"],
   )

   pkg_files(
       name = "partition_rootfs",
       srcs = [":system_qnx6fs"],
   )
   ```

1. Add the `diskimage` target:

   ```starlark
   load("@score_rules_imagefs//rules/qnx:diskimage.bzl", "diskimage")

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

The rule makes the partition images available to the `diskimage` action, but
it doesn't rewrite paths in the layout file. Write the paths in `disk.build`
as the action sees them.

The image is `bazel-bin/target_disk.img`. Set `gpt_enabled = False`, or omit
it, to build the disk without `-g`.

## Environment variables

The QNX toolchain sets the following variables for every image action. Paths
that start with `/proc/self/cwd/` point into the SDP inside the action's
working directory.

| Variable | Value |
|---|---|
| `QNX_HOST` | `/proc/self/cwd/` followed by the path of the SDP `host_dir` target |
| `QNX_TARGET` | `/proc/self/cwd/` followed by the path of the SDP `target_dir` target |
| `PATH` | `/proc/self/cwd/` followed by the `host_dir` path and `/usr/bin` |
| `QNX_CONFIGURATION_EXCLUSIVE` | `/var/tmp/.qnx` |
| `QNX_SHARED_LICENSE_FILE` | `/opt/score_qnx/license/licenses` |

The toolchain sets these values itself. You can't change them with the
`license_path` attribute of the `toolchain` tag.

### Use a license server

If you use a QNX license server, pass its address to the build. The toolchain
forwards the following variables from the Bazel action environment:

- `QNXLM_LICENSE_FILE`
- `LM_LICENSE_FILE`: if you don't set it, the toolchain uses the value of
  `QNXLM_LICENSE_FILE`.

To set a variable for every action, add it to your `.bazelrc`:

```text
build --action_env=QNXLM_LICENSE_FILE=LICENSE_SERVER
```

Replace `LICENSE_SERVER` with your license server address, for example in the
form `PORT@HOST`.
