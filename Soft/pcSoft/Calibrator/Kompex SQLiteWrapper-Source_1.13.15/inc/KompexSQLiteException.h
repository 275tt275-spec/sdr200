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

#ifndef KompexSQLiteException_H
#define KompexSQLiteException_H

#include <map>
#include <string>
#include <sstream>
#include <iostream>
#include "KompexSQLitePrerequisites.h"

namespace Kompex
{	
	//! Exception class for sqlite and KompexSQLiteWrapper errors
	class _SQLiteWrapperExport SQLiteException
	{
	public:
		//! Overloaded constructor
		SQLiteException(const std::string &filename, unsigned int lineNumber, std::string errDescription = "", int internalSqliteResultCode = -1):
		mErrorDescription(errDescription),
		mFilename(filename),
		mLineNumber(lineNumber),
		mInternalSqliteResultCode(internalSqliteResultCode)
		{
		}
		
		//! Overloaded constructor
		SQLiteException(const std::string &filename, unsigned int lineNumber, const char *errDescription = "", int internalSqliteResultCode = -1):
		mErrorDescription(std::string(errDescription)),
		mFilename(filename),
		mLineNumber(lineNumber),
		mInternalSqliteResultCode(internalSqliteResultCode)
		{
		}

		//! Shows all error information (filename, line, error message).\n
		//! Output: std::cerr
		inline void Show() const {std::cerr << "file: " << mFilename << "\nline number: " << mLineNumber << "\nerror: " << mErrorDescription << std::endl;}
		
		//! Get all error information (filename, line, error message) as std::string.
		std::string GetString() const 
		{
			std::stringstream strStream;
			strStream << "file: " << mFilename << "\nline number: " << mLineNumber << "\nerror: " << std::string(mErrorDescription) << "\n";
			return strStream.str();
		}

		//! Returns an error description.
		std::string GetErrorDescription() const {return mErrorDescription;}

		//! Returns the filename in which the error occured.
		std::string GetFilename() const {return mFilename;}

		//! Returns the line number in which the error occured.
		unsigned int GetLineNumber() const {return mLineNumber;}
		
		//! Returns the SQLite result code. It will also return extended result codes.\n
		//! Please refer to the following links to see the existing codes.\n
		//! SQLite Result Codes: http://sqlite.org/c3ref/c_abort.html \n
		//! SQLite Extended Result Codes: http://sqlite.org/c3ref/c_abort_rollback.html \n
		//! In case that this SQLiteWrapper will throw an own exception the result code will be -1.
		int GetSqliteResultCode() const {return mInternalSqliteResultCode;}

	private:
		//! Error description
		std::string mErrorDescription;
		//! Filename in which the error occured
		std::string mFilename;
		//! Line number in which the error occured
		unsigned int mLineNumber;
		//! Internal SQLite result code
		int mInternalSqliteResultCode;
	};
};

#endif // KompexSQLiteException_H

#ifndef KOMPEX_EXCEPT
#define KOMPEX_EXCEPT(errorString, internalSqliteResultCode) throw SQLiteException(__FILE__, __LINE__, errorString, internalSqliteResultCode)
#endif
