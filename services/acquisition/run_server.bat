@echo off
set "PATH=C:\Program Files\PostgreSQL\18\bin;C:\Program Files\OpenSSL-Win64\bin;%PATH%"
cd /d C:\dev\platform\oep_acquisition
build\src\app\oep_acquisition.exe config\config.toml
