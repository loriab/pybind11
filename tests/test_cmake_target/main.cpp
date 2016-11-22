// C++ file taken from https://github.com/pybind/cmake_example/blob/master/src/main.cpp

#include <pybind11/pybind11.h>

int add(int i, int j) {
    return i + j;
}

int subtract(int i, int j) {
    return i - j;
}

namespace py = pybind11;

PYBIND11_PLUGIN(test_cmake_target) {
    py::module m("test_cmake_target", R"pbdoc(
        Pybind11 example plugin
        -----------------------

        .. currentmodule:: test_cmake_target

        .. autosummary::
           :toctree: _generate

           add
           subtract
    )pbdoc");

    m.def("add", &add, R"pbdoc(
        Add two numbers

        Some other explanation about the add function.
    )pbdoc");

    m.def("subtract", &subtract, R"pbdoc(
        Subtract two numbers

        Some other explanation about the subtract function.
    )pbdoc");

#ifdef VERSION_INFO
    m.attr("__version__") = py::str(VERSION_INFO);
#else
    m.attr("__version__") = py::str("dev");
#endif

    return m.ptr();
}
