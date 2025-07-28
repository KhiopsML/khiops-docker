/* File: KhiopsNativeInterface.i */
%module KNI
%include "cstring.i"
%{
#include "KhiopsNativeInterface.h"
%}
%feature("autodoc", "1");

#define KNI_OK                            0
#define KNI_ErrorRunningFunction          (-1)    /* Other KNI function currently running: reentrant calls not allowed */
#define KNI_ErrorDictionaryFileName       (-2)    /* Bad dictionary file name */
#define KNI_ErrorDictionaryMissingFile    (-3)    /* Dictionary file does not exist */
#define KNI_ErrorDictionaryFileFormat     (-4)    /* Bad dictionary format: syntax error in dictionary file */
#define KNI_ErrorDictionaryName           (-5)    /* Bad dictionary name */
#define KNI_ErrorMissingDictionary        (-6)    /* Dictionary not found in dictionary file */
#define KNI_ErrorTooManyStreams           (-7)    /* Too many streams: number of simultaneously opened streams exceeds limit */
#define KNI_ErrorStreamHeaderLine         (-8)    /* Bad stream header line */
#define KNI_ErrorFieldSeparator           (-9)    /* Bad field separator */
#define KNI_ErrorStreamHandle             (-10)   /* Bad stream handle: handle does not relate to an opened stream */
#define KNI_ErrorStreamOpened             (-11)   /* Stream opened */
#define KNI_ErrorStreamNotOpened          (-12)   /* Stream not opened */
#define KNI_ErrorStreamInputRecord        (-13)   /* Bad input record: null-termination character not found before maximum string length */
#define KNI_ErrorStreamInputRead          (-14)   /* Problem in reading input record */
#define KNI_ErrorStreamOutputRecord       (-15)   /* Bad output record: output fields require more space than maximum string length */
#define KNI_ErrorMissingSecondaryHeader   (-16)   /* Missing specification of secondary table header */
#define KNI_ErrorMissingExternalTable     (-17)   /* Missing specification of external table */
#define KNI_ErrorDataRoot                 (-18)   /* Bad data root for an external table */
#define KNI_ErrorDataPath                 (-19)   /* Bad data path */
#define KNI_ErrorDataTableFile            (-20)   /* Bad data table file */
#define KNI_ErrorLoadDataTable            (-21)   /* Problem in loading external data tables */
#define KNI_ErrorMemoryOverflow           (-22)   /* Too much memory currently used */
#define KNI_ErrorStreamOpening            (-23)   /* Stream could not be opened */
#define KNI_ErrorStreamOpeningNotFinished (-24)   /* Multi-tables stream opening not finished */
#define KNI_ErrorLogFile                  (-25)   /* Bad error file */

int KNIGetVersion();
const char* KNIGetFullVersion();
int KNIOpenStream(const char* sDictionaryFileName, const char* sDictionaryName,
		const char* sStreamHeaderLine, char cFieldSeparator);
int KNICloseStream(int hStream);
%cstring_output_maxsize(char *sStreamOutputRecord, int nOutputMaxLength);
int KNIRecodeStreamRecord(int hStream, const char* sStreamInputRecord, char* sStreamOutputRecord, int nOutputMaxLength);
int KNISetSecondaryHeaderLine(int hStream, const char* sDataPath, const char* sStreamSecondaryHeaderLine);
int KNISetExternalTable(int hStream, const char* sDataRoot, const char* sDataPath, const char* sDataTableFileName);
int KNIFinishOpeningStream(int hStream);
int KNISetSecondaryInputRecord(int hStream, const char* sDataPath, const char* sStreamSecondaryInputRecord);
int KNIGetStreamMaxMemory();
int KNISetStreamMaxMemory(int nMaxMB);
int KNISetLogFileName(const char* sLogFileName);

