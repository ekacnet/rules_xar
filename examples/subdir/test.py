from examples.subdir.libfoo import foobar, foofoo
from examples.otherdir import bar

print("Called")
print(foofoo.func2())
print(foobar.func1())
print(bar.func3())
