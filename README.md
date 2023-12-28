# rules_xar
Rules_xar is a utility for creating xar self-contained python executables, similar to pex or par files.
It is leveraging Meta's [XAR](https://github.com/facebookincubator/xar/) format.

## Status

It's still an early version of the rules it only focus on creating `xar` for python, the github page for xar explains the advantage of using `xar` over zipfiles for python and hence it's the main focus for the moment.

## Setup

* Add the following to your WORKSPACE file (no support for `bzlmod` yet):

```python
http_archive(
    name = "rules_xar",
    sha256 = "737cd2ed1218e54a9db935f50c3a4df49b19506be31efb3adc1a5392379b2e81",
    strip_prefix = "rules_xar-0.0.2",
    url = "https://github.com/ekacnet/rules_xar/archive/refs/tags/v0.0.2.zip",
)
```

* Add the following to the top of any BUILD files that declare `xar_binary()` rules:

```python
load("@rules_xar//:xarify.bzl", "py_binary_xar")
```

## Usage

You need to have already a `py_binary` rule and then define a `py_binary_xar` one where the required parameters are:
* the name of the target, that will be the name of the file that you will generate
* the name of the `py_binary` target to use


For instance to create `test.xar` from the `test_py` target:

```python
py_binary_xar(
  name = "test.xar",
  main = ":test_py"
)
```

To build the `.xar` run the following command:

``` shell
bazel build //my/package:test.xar
```
The `.xar` file is created alongside the python stub and `.runfiles`
directories that py_binary() creates, but is independent of them.
It can be copied to other directories or machines, and executed
directly without needing the .runfiles directory. The body of the
`.xar` file contains all the srcs, deps, and data files listed in the `py_binary`.

## Options

### make_xar
This allows `py_binary_xar` to use an alternate binary for making the xar files, it needs to be an executable `bazel` target like `sh_binary` for instance.
See in `examples/custom_make_xar` for an example.
This is mainly when the _real_ `make_xar` binary is not the in path or if you need to invoke something before running it (ie. virtualenv)

### external_python_prefix
By default hermetic builds python runtime is included in the `xar` archive which incures a penalty when the archive is mounted. By using `external_python_prefix` it's possible to avoid that.
During the building of the archive the included runtime will be removed and reference to it replaced by a path constructed by appending the major and minor version of the "hermetic python" and the suffix `/bin/python3`.
It will be similar to this python string format:
```
{external_python_prefix}-{python_toolchain_major}.{python_toolchain_minor}/bin/python3
```

For instance if `external_python_prefix` is `/usr/local/python-bazel` and the python's toolchain version is 3.11 the constructed path will be:

```
/usr/local/python-bazel-3.11/bin/python3
```

This *obviously* expects that you provide a copy of the runtime on the host(s) where you want to run that `xar` file. The best (?) way to get the runtime is to create a dummy `py_binary` target and use a filegroup to get an easy access to the zip file.

```
filegroup(
    name = "py_runtime",
    srcs = [":dummy_binary"],
    output_group = "python_zip_file",
)

py_binary(
  name = "dummy_binary",
  srcs = ["empty.py"],
)
```

Extract the zip file and take the folder that starts with `rules_python` and you have your runtime.

## Limitations:

* Can currently only work with `py_binary`, in theory `xar` allows to pack pretty much anything especially with the `--raw` option but for the moment it's limited to python

## Example

Given a `BUILD` file with the following:

```python
load("@rules_xar//:xarify.bzl", "py_binary_xar")

py_binary_xar(
  name = "test.xar",
  main = ":test_py"
)

py_binary(
    name = 'test_py',
    srcs = ['foo.py', 'bar.py'],
    deps = ['//baz:some_py_lib'],
    data = ['quux.dat'],
)
```

Run the following build command:

``` shell
bazel build //package:test.xar
```

This results in the following files being created by bazel build:

```
bazel-bin/
    package/
        test_py
        test.xar
        test_py.runfiles/
            ...
```

The `.xar` file can be copied, moved, or renamed, and still run like a
compiled executable file:

```
$ scp bazel-bin/package/test.xar my-other-machine:test.xar
$ ssh my-other-machine ./foo.xar
```

More examples in the `examples` folder.

## System Requirements

* `make_xar` from [xar repository](https://github.com/facebookincubator/xar), you can install it with `pip install xar`
* `mksquashfs`, on Debian derived distros it's from the `squashfs-tools` package.
* Operating Systems: Linux and Unix derived ones.
