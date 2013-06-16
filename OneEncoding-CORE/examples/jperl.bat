@echo off
perl -MOneEncoding::CORE=cp932 %*
exit /B %ERRORLEVEL%
