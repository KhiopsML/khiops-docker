# Python binding for KNI

This is a python version of the Khiops Native Interface.

## Usage
All KNI functions are bound and can be used exactly like the C version. Simply import KNI in your python script.

```
 NAME
    KNI

FUNCTIONS
    KNICloseStream(hStream)
        KNICloseStream(int hStream) -> int
    
    KNIFinishOpeningStream(hStream)
        KNIFinishOpeningStream(int hStream) -> int
    
    KNIGetStreamMaxMemory()
        KNIGetStreamMaxMemory() -> int
    
    KNIGetVersion()
        KNIGetVersion() -> int
    
    KNIOpenStream(sDictionaryFileName, sDictionaryName, sStreamHeaderLine, cFieldSeparator)
        KNIOpenStream(char const * sDictionaryFileName, char const * sDictionaryName, char const * sStreamHeaderLine, char cFieldSeparator) -> int
    
    KNIRecodeStreamRecord(hStream, sStreamInputRecord, sStreamOutputRecord)
        KNIRecodeStreamRecord(int hStream, char const * sStreamInputRecord, char * sStreamOutputRecord) -> int
    
    KNISetExternalTable(hStream, sDataRoot, sDataPath, sDataTableFileName)
        KNISetExternalTable(int hStream, char const * sDataRoot, char const * sDataPath, char const * sDataTableFileName) -> int
    
    KNISetLogFileName(sLogFileName)
        KNISetLogFileName(char const * sLogFileName) -> int
    
    KNISetSecondaryHeaderLine(hStream, sDataPath, sStreamSecondaryHeaderLine)
        KNISetSecondaryHeaderLine(int hStream, char const * sDataPath, char const * sStreamSecondaryHeaderLine) -> int
    
    KNISetSecondaryInputRecord(hStream, sDataPath, sStreamSecondaryInputRecord)
        KNISetSecondaryInputRecord(int hStream, char const * sDataPath, char const * sStreamSecondaryInputRecord) -> int
    
    KNISetStreamMaxMemory(nMaxMB)
        KNISetStreamMaxMemory(int nMaxMB) -> int

```
 
## Building
To build, simply run:
```console
python3 setup.py sdist bdist_wheel
```

The build process requires standard python setuptools and swig for generating the C-python bindings. You may want to run install.sh to install them.

If the interface is modified (KhiopsNativeInterface.i) then the swig interface generation tool must be run again in order to regenerate the KNI.py and KhiopsNativeInterface_wrap.c files. An example invocation is provided in the compile.sh script.

## Installing
At some point the KNI package should be made available through artifactory. Until then, you have to build for yourself. If successfull, the installation package will be found in the dist folder. You can install it like this:
```console
pip3 install dist/KNI-0.1-cp38-cp38-linux_x86_64.whl <-- the filename may differ according to your arch/pyversion
```

## Examples
An example application making use of the package is provided under samples. Check out KNIRecodeFile.py. For an example invocation, take a look at recodeData.sh.

## Authors

* **Stephane Gouache** - *Main developer* - [GitLab Profile](https://gitlab.tech.orange/stephane.gouache)


