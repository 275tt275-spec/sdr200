
// Calibrator.h: главный файл заголовка для приложения PROJECT_NAME
//

#pragma once

#ifndef __AFXWIN_H__
	#error "включить pch.h до включения этого файла в PCH"
#endif

#include "resource.h"		// основные символы


// CCalibratorApp:
// Сведения о реализации этого класса: Calibrator.cpp
//

class CCalibratorApp : public CWinApp
{
public:
	CCalibratorApp();

// Переопределение
public:
	virtual BOOL InitInstance();

// Реализация

	DECLARE_MESSAGE_MAP()
};

extern CCalibratorApp theApp;
