This is a particular use case for xar, we are asking the wrapper to not include the python that `bazel` has picked and stuffed inside the zip archive but instead to use one based on a prefix specified in the target rule.
In order to make this example work you need to have a working python in the folder `/usr/local/python-bazel-3.11/bin`, the best way of obtaining it is to
run `bazel build //examples/external_python:test_zip`, extract the obtained zip file and use the folder `runfiles/rules_python~*~python~python_3_11_*`.
