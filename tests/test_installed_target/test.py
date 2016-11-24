import sys, os
sys.path.insert(1, os.getcwd())
import test_installed_target
assert test_installed_target.add(1, 2) == 3
print('test_installed_target imports and runs')

