@echo off
echo ===================================================
echo        NURSE APP - FRONTEND AND BACKEND LAUNCHER
echo ===================================================
echo.

echo Checking prerequisites...

:: Check if Node.js is installed
where node >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Node.js is not installed or not in PATH.
    echo Please install Node.js from https://nodejs.org/
    echo.
    goto :error
)

:: Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Flutter is not installed or not in PATH.
    echo Please install Flutter from https://flutter.dev/docs/get-started/install
    echo.
    goto :error
)

echo All prerequisites are met!
echo.

echo Starting Backend Server (Node.js)...
start cmd /k "cd nurse-backend && npm install && echo. && echo Backend dependencies installed. && echo. && npm start"

echo.
echo Waiting for backend to initialize...
timeout /t 8 /nobreak

echo.
echo Starting Frontend (Flutter)...
start cmd /k "flutter pub get && echo. && echo Flutter dependencies installed. && echo. && flutter run -d windows"

echo.
echo ===================================================
echo Both applications have been started successfully!
echo.
echo Backend: http://localhost:5000
echo Frontend: Running as Windows application
echo.
echo NOTE: You can close this window, but keep the other
echo       terminal windows open to keep the apps running.
echo ===================================================
echo.
goto :end

:error
echo.
echo Failed to start the application.
echo Please fix the errors above and try again.
echo.
pause
exit /b 1

:end
echo Press any key to exit this launcher window...
pause > nul
