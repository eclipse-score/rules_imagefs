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

def _directory_artifact_impl(ctx):
    directory = ctx.actions.declare_directory(ctx.label.name)
    ctx.actions.run_shell(
        outputs = [directory],
        command = (
            "mkdir -p {}/nested && printf '%s' ".format(directory.path) +
            "'hello from directory artifact' > {}/nested/hello.txt".format(directory.path)
        ),
    )
    return [DefaultInfo(files = depset([directory]))]

directory_artifact = rule(
    implementation = _directory_artifact_impl,
)
