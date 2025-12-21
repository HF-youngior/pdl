@echo off
echo SonarQube Java Fix Tool
echo ========================
echo.
echo Current Java version:
java -version
echo.
echo The issue is that SonarQube 9.9.0 has compatibility problems with Java 21.
echo.
echo SOLUTION 1: Set JAVA_HOME environment variable
echo 1. Open System Properties
echo 2. Advanced tab - Environment Variables
echo 3. New System Variable: JAVA_HOME = C:\Program Files\Java\jdk-21
echo 4. Add to Path: %JAVA_HOME%\bin
echo.
echo SOLUTION 2: Download compatible SonarQube version
echo Visit: https://www.sonarsource.com/downloads/
echo.
echo SOLUTION 3: Install Java 17 (Recommended for SonarQube 9.9.0)
echo Download from: https://adoptium.net/temurin/releases/?version=17
echo.
echo After applying any solution, restart SonarQube:
echo D:\sonarqube-9.9.0.65466\bin\windows-x86-64\StartSonar.bat
echo.
pause