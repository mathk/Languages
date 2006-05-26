
#include "PortableTruncate.h"

#ifdef _WIN32

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

// Win32 truncate by Mike Austin

int truncate(const char *path, long length)
{
    HANDLE file = CreateFile(path, GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
	
    if (file == INVALID_HANDLE_VALUE)
    {
		return -1;
    }
	
    if (SetFilePointer(file, length, NULL, FILE_BEGIN) == 0xFFFFFFFF || !SetEndOfFile(file))
    {
		CloseHandle(file);
		return -1;
    }
	
    CloseHandle(file);
    return 0;
}

#endif

#if defined(__SYMBIAN32__)
int truncate(const char* path, long length)
{
  // TODO: Implement for Symbian
	return -1;
}
#endif
