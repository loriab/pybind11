cmake_minimum_required(VERSION 3.0)
project(test_installed_target CXX)

set(CMAKE_MODULE_PATH "")

find_package(pybind11 CONFIG REQUIRED)
#find_package(PythonLibsNew MODULE REQUIRED)

message(STATUS "Found pybind11: ${pybind11_INCLUDE_DIRS} (found version ${pybind11_VERSION})")
message(STATUS "Found Python: ${PYTHON_INCLUDE_DIRS} (found version ${PYTHON_VERSION_STRING})")

#set_property(TARGET pybind11::pybind11 APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${PYTHON_INCLUDE_DIRS})
#set_property(TARGET pybind11::pybind11 APPEND PROPERTY INTERFACE_COMPILE_OPTIONS "${PYBIND11_CPP_STANDARD}")

add_library(test_installed_target MODULE main.cpp)

target_link_libraries(test_installed_target pybind11::pybind11)

# make sure result is, for example, test_installed_target.so, not libtest_installed_target.dylib
set_target_properties(test_installed_target PROPERTIES PREFIX "${PYTHON_MODULE_PREFIX}"
                                                       SUFFIX "${PYTHON_MODULE_EXTENSION}")

