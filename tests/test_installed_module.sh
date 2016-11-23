#!/bin/bash

# need an installed pybind11 from which to grab target
cd .. && make && make install

# enter mini CMake setup
cd tests/test_installed_module/

# configure and build mini CMake setup
cmake -H. -Bbuild \
      -DCMAKE_CXX_COMPILER=@CMAKE_CXX_COMPILER@ \
      -DCMAKE_PREFIX_PATH=@CMAKE_INSTALL_PREFIX@ \
      -DPYBIND11_CPP_STANDARD="@PYBIND11_CPP_STANDARD@" \
      -DPythonLibsNew_FIND_VERSION="@PYBIND11_PYTHON_VERSION@"
cd build && make

# test importable
@PYTHON_EXECUTABLE@ -c "import test_installed_module; assert test_installed_module.add(11, 22) == 33; print('test_installed_module imports and runs')"
