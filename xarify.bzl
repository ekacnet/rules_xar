def collect_transitive_srcs(ctx):
    transitive_srcs = depset(order = "compile")
    for dep in ctx.attr.deps:
        transitive_srcs += dep.transitive_srcs

    #transitive_srcs += python_file_types.filter(ctx.files.srcs)
    return transitive_srcs

def _gen_exec_wrapper(main_cmd):
    return """#!/bin/bash

dir=$(dirname $0)
name=$(basename "$1")
shift
exec "$dir"/{cmd} "$@" """.format(cmd = main_cmd.basename)

def _gen_xar_exec_wrapper(make_xar_cmd):
    return """#!/bin/bash
current=$(pwd)
zip_file=$(basename $1)
zip_directory=$(dirname $1)
main=$(basename $2)
main_dir=$(dirname $2)
wrapper=$3
output=$4

if [ "$zip_directory" != "$main_dir" ]; then
  mv "$1" "$zip_directory"
  mv "$2" "$zip_directory"
fi
if [[ $(echo "$output" |cut -c1 ) != "/" ]]; then
  output="$current/$output"
fi
cd "$zip_directory"
unzip "$zip_file" >/dev/null
rm __main__.py __init__.py
mv runfiles "$main.runfiles"
rm "$zip_file"
sed -i 's/args = sys.argv.*/args = sys.argv[2:]/' "$main"
rm "xar_exec_wrapper"
{cmd} --raw  . --raw-executable "$(basename $wrapper)" --output "$output" &>/dev/null
""".format(cmd = make_xar_cmd)

def _xar_binary_impl(ctx):
    # We will use the python_zil_file that py_binary _can_ generate_
    python_zip = ctx.attr.src[OutputGroupInfo]["python_zip_file"].to_list()[0]

    # Find the main entry point
    main_file = ctx.attr.main.files_to_run.executable
    if main_file not in ctx.attr.src.data_runfiles.files.to_list():
        fail("Main entry point [%s] not listed in srcs" % main_file, "main")

    # Find the list of things that must be built before this thing is built
    # TODO: also handle ctx.attr.src.data_runfiles.symlinks
    inputs = ctx.attr.src.default_runfiles.files.to_list()

    # Add the zero-length __init__.py files:  ctx.attr.src.default_runfiles.empty_filenames.to_list():

    # Regular (source and generated) files: inputs

    tgt_exec_wrapper = ctx.actions.declare_file("{}_wrapper".format(main_file.basename))
    ctx.actions.write(
        output = tgt_exec_wrapper,
        content = _gen_exec_wrapper(main_file),
        is_executable = True,
    )

    if ctx.executable.make_xar == None:
        make_xar_name = "make_xar"
    else:
        make_xar_name = ctx.executable.make_xar.filename

    xar_exec_wrapper = ctx.actions.declare_file("xar_exec_wrapper")
    ctx.actions.write(
        output = xar_exec_wrapper,
        content = _gen_xar_exec_wrapper(make_xar_name),
        is_executable = True,
    )

    # Find the list of directories to add to sys.path
    import_roots = ctx.attr.src[PyInfo].imports.to_list()

    # Inputs to the action, but don't actually get stored in the .par file
    extra_inputs = [
        main_file,
        tgt_exec_wrapper,
    ]
    # The MANIFEST file that py_binary is creating: ctx.attr.src.files_to_run.runfiles_manifest,

    # Assemble command line for .par compiler
    args = [
        python_zip.path,
        main_file.path,
        tgt_exec_wrapper.path,
        ctx.outputs.executable.path,
    ]

    # TODO do something with that maybe
    for import_root in import_roots:
        print(import_root)

    all_inputs = depset(transitive = [d for d in [depset(extra_inputs), ctx.attr.src[OutputGroupInfo]["python_zip_file"]]])
    ctx.actions.run(
        inputs = all_inputs,
        outputs = [ctx.outputs.executable],
        progress_message = "Building xar file %s" % ctx.label,
        executable = xar_exec_wrapper,
        arguments = args,
        use_default_shell_env = True,
        mnemonic = "MakeXar",
    )

    # .par file itself has no runfiles and no providers
    return []

xar_binary = rule(
    implementation = _xar_binary_impl,
    attrs = {
        #"src": attr.label(mandatory = True),
        "main": attr.label(
            mandatory = True,
        ),
        "src": attr.label(
            mandatory = True,
        ),
        "make_xar": attr.label(
            executable = True,
            cfg = "exec",
        ),
    },
    executable = True,
)
