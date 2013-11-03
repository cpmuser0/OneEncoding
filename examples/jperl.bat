@echo off
perl -MOneEncoding=sjis_escape %*
exit /B %ERRORLEVEL%
