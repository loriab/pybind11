# CMakeLists.txt -- Build system for the pybind11 modules
#
# Copyright (c) 2015 Wenzel Jakob <wenzel@inf.ethz.ch>
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

cmake_minimum_required(VERSION 2.8.12)

#project(pybind11)

# Check if pybind11 is being used directly or via add_subdirectory
#set(PYBIND11_MASTER_PROJECT OFF)
#if (CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
#  set(PYBIND11_MASTER_PROJECT ON)
#endif()

#option(PYBIND11_INSTALL "Install pybind11 header files?" ${PYBIND11_MASTER_PROJECT})
#option(PYBIND11_TEST    "Build pybind11 test suite?"     ${PYBIND11_MASTER_PROJECT})
option(PYBIND11_WERROR  "Report all warnings as errors"  OFF)

# Add a CMake parameter for choosing a desired Python version
set(PYBIND11_PYTHON_VERSION "" CACHE STRING "Python version to use for compiling modules")

#list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/tools")
set(Python_ADDITIONAL_VERSIONS 3.4 3.5 3.6 3.7)
find_package(PythonLibsNew ${PYBIND11_PYTHON_VERSION} REQUIRED)

include(CheckCXXCompilerFlag)

function(select_cxx_standard)
  if(NOT MSVC AND NOT PYBIND11_CPP_STANDARD)
    check_cxx_compiler_flag("-std=c++14" HAS_CPP14_FLAG)
    check_cxx_compiler_flag("-std=c++11" HAS_CPP11_FLAG)
  
    if (HAS_CPP14_FLAG)
      set(PYBIND11_CPP_STANDARD -std=c++14)
    elseif (HAS_CPP11_FLAG)
      set(PYBIND11_CPP_STANDARD -std=c++11)
    else()
      message(FATAL_ERROR "Unsupported compiler -- pybind11 requires C++11 support!")
    endif()
  
    set(PYBIND11_CPP_STANDARD ${PYBIND11_CPP_STANDARD} CACHE STRING
        "C++ standard flag, e.g. -std=c++11 or -std=c++14. Defaults to latest available." FORCE)
  endif()
endfunction()

# Cache variables so pybind11_add_module can be used in parent projects
#set(PYBIND11_INCLUDE_DIR "${CMAKE_CURRENT_LIST_DIR}/include" CACHE INTERNAL "")
#set(PYTHON_INCLUDE_DIRS ${PYTHON_INCLUDE_DIRS} CACHE INTERNAL "")
#set(PYTHON_LIBRARIES ${PYTHON_LIBRARIES} CACHE INTERNAL "")
#set(PYTHON_MODULE_PREFIX ${PYTHON_MODULE_PREFIX} CACHE INTERNAL "")
#set(PYTHON_MODULE_EXTENSION ${PYTHON_MODULE_EXTENSION} CACHE INTERNAL "")

# Build a Python extension module:
# pybind11_add_module(<name> [MODULE | SHARED] [EXCLUDE_FROM_ALL] source1 [source2 ...])
#
function(pybind11_add_module target_name)
  set(lib_type "MODULE")
  set(do_lto True)
  set(exclude_from_all "")
  set(sources "")

  set(_args_to_try "${ARGN}")
  foreach(_ex_arg IN LISTS _args_to_try)
    if(${_ex_arg} STREQUAL "MODULE")
      set(lib_type "MODULE")
    elseif(${_ex_arg} STREQUAL "SHARED")
      set(lib_type "SHARED")
    elseif(${_ex_arg} STREQUAL "EXCLUDE_FROM_ALL")
      set(exclude_from_all "EXCLUDE_FROM_ALL")
    else()
      list(APPEND sources "${_ex_arg}")
    endif()
  endforeach()

  add_library(${target_name} ${lib_type} ${exclude_from_all} ${sources})

  target_include_directories(${target_name}
    PRIVATE ${PYBIND11_INCLUDE_DIR}  # from project CMakeLists.txt
    PRIVATE ${pybind11_INCLUDE_DIR}  # from pybind11Config
    PRIVATE ${PYTHON_INCLUDE_DIRS})

  # The prefix and extension are provided by FindPythonLibsNew.cmake
  set_target_properties(${target_name} PROPERTIES PREFIX "${PYTHON_MODULE_PREFIX}")
  set_target_properties(${target_name} PROPERTIES SUFFIX "${PYTHON_MODULE_EXTENSION}")

  if(WIN32 OR CYGWIN)
    # Link against the Python shared library on Windows
    target_link_libraries(${target_name} PRIVATE ${PYTHON_LIBRARIES})
  elseif(APPLE)
    # It's quite common to have multiple copies of the same Python version
    # installed on one's system. E.g.: one copy from the OS and another copy
    # that's statically linked into an application like Blender or Maya.
    # If we link our plugin library against the OS Python here and import it
    # into Blender or Maya later on, this will cause segfaults when multiple
    # conflicting Python instances are active at the same time (even when they
    # are of the same version).

    # Windows is not affected by this issue since it handles DLL imports
    # differently. The solution for Linux and Mac OS is simple: we just don't
    # link against the Python library. The resulting shared library will have
    # missing symbols, but that's perfectly fine -- they will be resolved at
    # import time.

    target_link_libraries(${target_name} PRIVATE "-undefined dynamic_lookup")
  endif()

  select_cxx_standard()
  if(NOT MSVC)
    # Make sure C++11/14 are enabled
    target_compile_options(${target_name} PUBLIC ${PYBIND11_CPP_STANDARD})

    # Enable link time optimization and set the default symbol
    # visibility to hidden (very important to obtain small binaries)
    string(TOUPPER "${CMAKE_BUILD_TYPE}" U_CMAKE_BUILD_TYPE)
    if (NOT ${U_CMAKE_BUILD_TYPE} MATCHES DEBUG)
      # Check for Link Time Optimization support (GCC/Clang)
      check_cxx_compiler_flag("-flto" HAS_LTO_FLAG)
      if(HAS_LTO_FLAG AND NOT CYGWIN)
        target_compile_options(${target_name} PRIVATE -flto)
      endif()

      # Intel equivalent to LTO is called IPO
      if(CMAKE_CXX_COMPILER_ID MATCHES "Intel")
        check_cxx_compiler_flag("-ipo" HAS_IPO_FLAG)
        if(HAS_IPO_FLAG)
          target_compile_options(${target_name} PRIVATE -ipo)
        endif()
      endif()

      # Default symbol visibility
      target_compile_options(${target_name} PRIVATE "-fvisibility=hidden")

      # Strip unnecessary sections of the binary on Linux/Mac OS
      if(CMAKE_STRIP)
        if(APPLE)
          add_custom_command(TARGET ${target_name} POST_BUILD
                             COMMAND ${CMAKE_STRIP} -u -r $<TARGET_FILE:${target_name}>)
        else()
          add_custom_command(TARGET ${target_name} POST_BUILD
                             COMMAND ${CMAKE_STRIP} $<TARGET_FILE:${target_name}>)
        endif()
      endif()
    endif()
  elseif(MSVC)
    # /MP enables multithreaded builds (relevant when there are many files), /bigobj is
    # needed for bigger binding projects due to the limit to 64k addressable sections
    target_compile_options(${target_name} PRIVATE /MP /bigobj)

    # Enforce link time code generation on MSVC, except in debug mode
    target_compile_options(${target_name} PRIVATE $<$<NOT:$<CONFIG:Debug>>:/GL>)

    # Fancy generator expressions don't work with linker flags, for reasons unknown
    set_property(TARGET ${target_name} APPEND_STRING PROPERTY LINK_FLAGS_RELEASE /LTCG)
    set_property(TARGET ${target_name} APPEND_STRING PROPERTY LINK_FLAGS_MINSIZEREL /LTCG)
    set_property(TARGET ${target_name} APPEND_STRING PROPERTY LINK_FLAGS_RELWITHDEBINFO /LTCG)
  endif()

  message("building module ${target_name}")
  message("lib_type ${lib_type}")
  message("exclude_from_all ${exclude_from_all}")
  message("sources ${sources}")
  get_property(_py TARGET ${target_name} PROPERTY INCLUDE_DIRECTORIES)
  get_property(_cxx TARGET ${target_name} PROPERTY COMPILE_OPTIONS)
  message("info from pybind11_add_module ${_py} ${_cxx}")

endfunction()

# Compile with compiler warnings turned on
function(pybind11_enable_warnings target_name)
  if(MSVC)
    target_compile_options(${target_name} PRIVATE /W4)
  else()
    target_compile_options(${target_name} PRIVATE -Wall -Wextra -Wconversion)
  endif()

  if(PYBIND11_WERROR)
    if(MSVC)
      target_compile_options(${target_name} PRIVATE /WX)
    else()
      target_compile_options(${target_name} PRIVATE -Werror)
    endif()
  endif()
endfunction()

#set(PYBIND11_HEADERS
#  include/pybind11/attr.h
#  include/pybind11/cast.h
#  include/pybind11/chrono.h
#  include/pybind11/common.h
#  include/pybind11/complex.h
#  include/pybind11/descr.h
#  include/pybind11/options.h
#  include/pybind11/eigen.h
#  include/pybind11/eval.h
#  include/pybind11/functional.h
#  include/pybind11/numpy.h
#  include/pybind11/operators.h
#  include/pybind11/pybind11.h
#  include/pybind11/pytypes.h
#  include/pybind11/stl.h
#  include/pybind11/stl_bind.h
#  include/pybind11/typeid.h
#)
#string(REPLACE "include/" "${CMAKE_CURRENT_SOURCE_DIR}/include/"
#       PYBIND11_HEADERS "${PYBIND11_HEADERS}")
#
#if (PYBIND11_TEST)
#  add_subdirectory(tests)
#endif()

#include(GNUInstallDirs)
#include(CMakePackageConfigHelpers)

#if(NOT (CMAKE_VERSION VERSION_LESS 3.0))  # CMake >= 3.0

#  file(STRINGS "${PYBIND11_INCLUDE_DIR}/pybind11/common.h" pybind11_version_defines
#       REGEX "#define PYBIND11_VERSION_(MAJOR|MINOR|PATCH) ")
#  foreach(ver ${pybind11_version_defines})
#    if (ver MATCHES "#define PYBIND11_VERSION_(MAJOR|MINOR|PATCH) +([^ ]+)$")
#      set(PYBIND11_VERSION_${CMAKE_MATCH_1} "${CMAKE_MATCH_2}" CACHE INTERNAL "")
#    endif()
#  endforeach()
#  set(${PROJECT_NAME}_VERSION ${PYBIND11_VERSION_MAJOR}.${PYBIND11_VERSION_MINOR}.${PYBIND11_VERSION_PATCH})
#
#  # Build an interface library target:
#  #   Though any project using pybind11 will need to include python headers and
#  #   define c++11/14-ness, these are not included as interface includes or compile
#  #   defs because (1) that's really the domain of the upstream project to decide,
#  #   (2) we can get away with it since installation (headers) don't care about
#  #   python version or C++ standard, and (3) this will make the easily target relocatable.
#  add_library(pybind11 INTERFACE)
#  target_include_directories(pybind11 INTERFACE $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
#  if(APPLE)
#      target_link_libraries(pybind11 INTERFACE "-undefined dynamic_lookup")
#  endif()
#endif()
#
#if (PYBIND11_INSTALL)
#  install(FILES ${PYBIND11_HEADERS}
#          DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/pybind11)
#  if(NOT (CMAKE_VERSION VERSION_LESS 3.0))
#    install(TARGETS pybind11
#            EXPORT "${PROJECT_NAME}Targets")
#
#        # explicit "share" not "DATADIR" for CMake search path
#    set(CMAKECONFIG_INSTALL_DIR "share/cmake/${PROJECT_NAME}")
#    configure_package_config_file(tools/${PROJECT_NAME}Config.cmake.in
#                                  "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake"
#                                  INSTALL_DESTINATION ${CMAKECONFIG_INSTALL_DIR})
#    write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
#                                     VERSION ${${PROJECT_NAME}_VERSION}
#                                     COMPATIBILITY AnyNewerVersion)
#    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
#                  ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
#                  tools/FindPythonLibsNew.cmake
#            DESTINATION ${CMAKECONFIG_INSTALL_DIR})
#    install(EXPORT "${PROJECT_NAME}Targets"
#            NAMESPACE "${PROJECT_NAME}::"
#            DESTINATION ${CMAKECONFIG_INSTALL_DIR})
#    message(STATUS "Exporting ${PROJECT_NAME}::pybind11 interface library target version ${${PROJECT_NAME}_VERSION}")
#  endif()
#endif()
