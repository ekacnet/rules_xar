from libfoo import foobar, foofoo
from otherdir import bar
import time

print("Called")
time.sleep(120)
print(foofoo.func2())
print(foobar.func1())
print(bar.func3())
