<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# Get started with ext4 images

In this tutorial, you create a small Bazel workspace and build an ext4
filesystem image from it. The `ext4` rule needs no QNX software, so it's the
quickest way to try the module. When you finish, you have an image that
contains a text file and a symbolic link, and you have checked its contents.

This tutorial doesn't cover QNX images. For those, see
[Build QNX images](qnx-images.md).

## Before you begin

You need:

- An x86_64 Linux machine. The `ext4` toolchain runs only on x86_64 Linux
  hosts.
- [Bazelisk](https://github.com/bazelbuild/bazelisk) or Bazel. This
  repository uses Bazel 8.8.2 (see [.bazelversion](../.bazelversion)).
- A C compiler. Bazel compiles `mke2fs` from source during the first build.
- Network access to `github.com` (for the e2fsprogs source) and to the two
  Bazel registries that the next section configures.
- Optional: the `debugfs` tool from e2fsprogs, to inspect the finished image.

## Create the workspace

1. Create an empty directory and change to it.

1. Create a file named `.bazelrc` with the following content. The first
   registry provides the S-CORE modules that `score_rules_imagefs` depends on.
   The second provides everything else.

   ```text
   common --registry=https://raw.githubusercontent.com/eclipse-score/bazel_registry/main/
   common --registry=https://bcr.bazel.build
   ```

1. Create a file named `MODULE.bazel`:

   ```starlark
   module(name = "my_images")

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

   Replace `VERSION` with the release of `score_rules_imagefs` that you want
   to use. To try a local checkout instead, drop the `version` argument and add
   an override:

   ```starlark
   local_path_override(
       module_name = "score_rules_imagefs",
       path = "/path/to/rules_imagefs",
   )
   ```

   Replace `/path/to/rules_imagefs` with the path to your checkout.

1. Create a file named `hello.txt` with the content `hello from docs`.

1. Create a file named `BUILD`:

   ```starlark
   load("@rules_pkg//pkg:mappings.bzl", "pkg_files", "pkg_mklink")
   load("@score_rules_imagefs//rules/linux:ext4.bzl", "ext4")

   pkg_files(
       name = "rootfs_files",
       srcs = ["hello.txt"],
       prefix = "etc",
   )

   pkg_mklink(
       name = "hello_link",
       link_name = "usr/share/hello.txt",
       target = "/etc/hello.txt",
   )

   ext4(
       name = "rootfs_ext4",
       srcs = [
           ":hello_link",
           ":rootfs_files",
       ],
   )
   ```

   The `pkg_files` target places `hello.txt` at `/etc/hello.txt` in the image.
   The `pkg_mklink` target creates the link `/usr/share/hello.txt`, which
   points to `/etc/hello.txt`. The `ext4` rule collects both.

## Build the image

1. Run the following command:

   ```shell
   bazel build //:rootfs_ext4
   ```

   The first build takes longer than later builds because Bazel downloads the
   e2fsprogs source and compiles `mke2fs`. The output ends with lines like
   these:

   ```text
   Target //:rootfs_ext4 up-to-date:
     bazel-bin/rootfs_ext4.ext4
   INFO: Build completed successfully
   ```

1. Confirm that the image exists at `bazel-bin/rootfs_ext4.ext4`.

## Verify the image

1. Read the file from inside the image:

   ```shell
   debugfs -R "cat /etc/hello.txt" bazel-bin/rootfs_ext4.ext4
   ```

   The output includes the following line:

   ```text
   hello from docs
   ```

1. Check that the link exists:

   ```shell
   debugfs -R "stat /usr/share/hello.txt" bazel-bin/rootfs_ext4.ext4
   ```

   The first line of the output contains `Type: symlink`.

## What's next

- To change which `mke2fs` and `coreutils` the rule uses, see
  [Configure toolchains](toolchains.md).
- For every attribute of the `ext4` rule, see the
  [rule reference](rules.md#ext4).
- To learn how the image is built, see [How it works](how-it-works.md).
- If the build fails with `No matching toolchains found`, see
  [Troubleshooting](troubleshooting.md).
