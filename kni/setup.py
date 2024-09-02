#!/usr/bin/env python
# -*- coding: latin-1 -*-
"""
setup.py file for KNI wrapper
"""

from setuptools import setup, find_packages, Extension

with open("README.md", "r") as fh:
    long_description = fh.read()
    
kni_module = Extension('_KNI',
                       sources=['KhiopsNativeInterface_wrap.c'],
                       libraries = ['KhiopsNativeInterface'],
                       runtime_library_dirs=['.'],
                       library_dirs = ['.'],
                       extra_compile_args=['-O0'])

setup (name = 'KNI',
       version = '0.1',
       author      = "Stéphane Gouache",
       author_email= "stephane.gouache@orange.com",
       description = """Python module KNI (KhiopsNativeInterface)""",
       long_description=long_description,
       url="https://gitlab.tech.orange/khiops-tools/python-kni",
       packages=find_packages(),
       ext_modules = [kni_module],
       py_modules = ["KNI"],
       python_requires='>=3.6',
       )
