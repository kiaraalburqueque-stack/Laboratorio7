@echo off
setlocal
cd /d "%~dp0.."
if not defined JAVA_HOME (
  for /d %%J in ("C:\Program Files\Java\jdk-*" "C:\Program Files\Eclipse Adoptium\jdk-*") do set "JAVA_HOME=%%~J"
)
echo Access Lab - modo demostracion con H2
echo Al iniciar el servidor, abre http://localhost:8080
call mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=demo"
if errorlevel 1 pause
endlocal
