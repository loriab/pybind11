import sys, os
sys.path.insert(1, os.getcwd())
import test_installed_module
assert test_installed_module.add(11, 22) == 33
print('test_installed_module imports and runs')
