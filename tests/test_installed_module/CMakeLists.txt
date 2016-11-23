cmake_minimum_required(VERSION 2.8.12)
project(test_installed_module CXX)

set(CMAKE_MODULE_PATH "")

find_package(pybind11 CONFIG REQUIRED)
include(pybind11Tools)
#find_package(PythonLibsNew MODULE REQUIRED)

message(STATUS "Found pybind11: ${pybind11_INCLUDE_DIRS} (found version ${pybind11_VERSION})")
#message(STATUS "Found Python: ${PYTHON_INCLUDE_DIRS} (found version ${PYTHON_VERSION_STRING})")

#set_property(TARGET pybind11::pybind11 APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${PYTHON_INCLUDE_DIRS})
#set_property(TARGET pybind11::pybind11 APPEND PROPERTY INTERFACE_COMPILE_OPTIONS "${PYBIND11_CPP_STANDARD}")

pybind11_add_module(test_installed_module SHARED main.cpp)
#add_library(test_installed_module MODULE main.cpp)

#target_link_libraries(test_installed_module pybind11::pybind11)

# make sure result is, for example, test_installed_module.so, not libtest_installed_module.dylib
#set_target_properties(test_installed_module PROPERTIES PREFIX "${PYTHON_MODULE_PREFIX}"
#                                                       SUFFIX "${PYTHON_MODULE_EXTENSION}")

