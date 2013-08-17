@echo off
perl -MOneEncoding::Filter -MOneEncoding::CORE=cp932 %*
exit /B %ERRORLEVEL%
