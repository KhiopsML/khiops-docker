#!/bin/bash

# Swig binding generation needs to be done only upon binding modification
swig4.0 -python KhiopsNativeInterface.i

# Binding compilation
python3 setup.py sdist bdist_wheel
