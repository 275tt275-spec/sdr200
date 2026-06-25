/*
	This file is part of Kompex SQLite Wrapper.
	Copyright (c) 2008-2024 Sven Broeske

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/

#ifndef KompexSQLitePrerequisites_H
#define KompexSQLitePrerequisites_H

#if _WIN32
	#define _CDECL _cdecl
	#if defined(_KOMPEX_SQLITEWRAPPER_EXPORT) && defined(_KOMPEX_SQLITEWRAPPER_DYN)
		#define _SQLiteWrapperExport __declspec(dllexport)
	#elif defined(_KOMPEX_SQLITEWRAPPER_DYN)
		#define _SQLiteWrapperExport __declspec(dllimport)
	#else
		#define _SQLiteWrapperExport
	#endif
#else
	#define _SQLiteWrapperExport
#endif

namespace Kompex
{
	#if defined(_MSC_VER) || defined(__BORLANDC__)
		typedef __int64 int64;
		typedef unsigned __int64 uint64;
	#else
		typedef long long int int64;
		typedef unsigned long long int uint64;
	#endif
};

#endif // KompexSQLitePrerequisites_H
