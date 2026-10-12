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
