@echo off
perl -MOneEncoding=cp932 %*
exit /B %ERRORLEVEL%
