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

#ifndef KompexSQLiteCerrRedirection_H
#define KompexSQLiteCerrRedirection_H

#include <fstream>
#include <iostream>
#include "KompexSQLitePrerequisites.h"

namespace Kompex
{
	//! Base-class for std redirections
	class _SQLiteWrapperExport Redirection
	{
	public:
		//! Standard constructor
		Redirection() 
		{
			pOutputFile = new std::ofstream();
		}
		//! Destrctor
		virtual ~Redirection() 	
		{
			delete pOutputFile;
		}

	protected:
		//! File handle
		std::ofstream *pOutputFile;
		//! Stream buffer
		std::streambuf *mBuffer;

	private:
		//! Copy constrctor
		Redirection(const Redirection& r);
		//! Assignment operator
		Redirection& operator=(const Redirection& r) {return *this;} 
	};

	//! std::cerr redirection.
	class _SQLiteWrapperExport CerrRedirection : public Redirection
	{
	public:
		//! Overloaded constructor
		CerrRedirection(const std::string &filename)
		{
			pOutputFile->open(filename.c_str(), std::ios_base::out);
			std::streambuf *errbuf = pOutputFile->rdbuf();
			mBuffer = std::cerr.rdbuf();
			std::cerr.rdbuf(errbuf);
		};
		//! Destrctor
		virtual ~CerrRedirection()
		{
			std::cerr.rdbuf(mBuffer);
		}

	private:
		//! Copy constrctor
		CerrRedirection(const CerrRedirection& cr) {}
		//! Assignment operator
		CerrRedirection& operator=(const CerrRedirection& cr) {return *this;} 
	};

	//! std::cout redirection.
	class _SQLiteWrapperExport CoutRedirection : public Redirection
	{
	public:
		//! Overloaded constructor
		CoutRedirection(const std::string &filename)
		{
			pOutputFile->open(filename.c_str(), std::ios_base::out);
			std::streambuf *buf = pOutputFile->rdbuf();
			mBuffer = std::cout.rdbuf();
			std::cout.rdbuf(buf);
		};
		//! Destrctor
		virtual ~CoutRedirection()
		{
			std::cerr.rdbuf(mBuffer);
		}

	private:
		//! Copy constrctor
		CoutRedirection(const CoutRedirection& cr) {}
		//! Assignment operator
		CoutRedirection& operator=(const CoutRedirection& cr) {return *this;} 
	};

};

#endif // KompexSQLiteCerrRedirection_H
