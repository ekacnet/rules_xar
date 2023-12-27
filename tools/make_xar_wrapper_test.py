import os
import sys
import shutil
import zipfile
import unittest
from unittest import TestCase, mock
from tools.make_xar_wrapper import main


def run_mock(*args, **kwargs):
    return mock.Mock(returncode=0, stdout=b"Python 3.12", stderr=b"")


class TestMain(TestCase):
    def setUp(self):
        # Create a temporary directory for testing
        self.test_directory = "test_directory"
        self.current = os.getcwd()
        try:
            shutil.rmtree(self.test_directory)
        except:  # noqa E721
            pass
        os.mkdir(self.test_directory)
        os.chdir(self.test_directory)

    def tearDown(self):
        # Remove the temporary directory and its contents after testing
        os.chdir(f"{self.current}/")
        shutil.rmtree(self.test_directory)

    @mock.patch("subprocess.run")
    def test_main(self, mock_run):
        # Create dummy files for testing
        make_xar_binary = "make_xar_binary"
        out_of_archive_python_prefix = "out_of_archive_python_prefix"
        zip_file_name = "test.zip"
        zip_directory = "zip_directory"
        base_directory = "somedir"
        # It's the binary that bazel will create for a python_binary
        main_file_fullpath = f"{base_directory}/main.py"
        wrapper = "wrapper.py"
        output = "output.xar"
        python_bin_name = "something-python"

        os.makedirs(zip_directory)
        os.makedirs(base_directory)
        os.makedirs(f"runfiles/{python_bin_name}/bin")

        for n in ["__main__.py", "__init__.py"]:
            with open(n, "w") as main_file:
                main_file.write("something")

        # Create a fake python binary so that the main function can change the
        # execution bits
        with open(f"runfiles/{python_bin_name}/bin/python", "w") as file:
            file.write("""#!/bin/bash""")

        with zipfile.ZipFile(f"{zip_directory}/{zip_file_name}", "w") as zip_ref:
            for n in ["__main__.py", "__init__.py"]:
                zip_ref.write(n)
            zip_ref.write(f"runfiles/{python_bin_name}/bin/python")

        with open(main_file_fullpath, "w") as main_file:
            main_file.write(f"PYTHON_BINARY = '{python_bin_name}'\nargs = sys.argv[1:]")

        with open(wrapper, "w") as wrapper_file:
            wrapper_file.write("wrapper")
        mock_run.side_effect = run_mock
        # Set the command line arguments
        sys.argv = [
            "test_main",
            make_xar_binary,
            out_of_archive_python_prefix,
            f"{zip_directory}/{zip_file_name}",
            main_file_fullpath,
            wrapper,
            output,
        ]

        # Call the main function
        main()
        os.chdir(f"{self.current}/{self.test_directory}")

        # Assertion statements to check the expected outputs
        self.assertTrue(os.path.isdir(f"{zip_directory}/out"))
        self.assertTrue(os.path.isfile(f"{zip_directory}/out/wrapper.py"))
        self.assertTrue(os.path.isfile(f"{zip_directory}/out/main.py"))

        with open(f"{zip_directory}/out/main.py", "r") as new_main:
            content = new_main.read()
            self.assertIn(
                f"PYTHON_BINARY = '{out_of_archive_python_prefix}-3.12/bin/python3'",
                content,
            )
            self.assertIn("args = sys.argv[2:]", content)

        mock_run.assert_called_with(
            [
                make_xar_binary,
                "--raw",
                ".",
                "--raw-executable",
                "wrapper.py",
                "--output",
                f"{self.current}/{self.test_directory}/{output}",
            ],
            capture_output=True,
        )
        mock_run.ass


if __name__ == "__main__":
    unittest.main()
