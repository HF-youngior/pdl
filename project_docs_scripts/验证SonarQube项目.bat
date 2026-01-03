@echo off
echo ========================================
echo SonarQube Project Verification Script
echo ========================================

echo Checking if project 'pdl' exists on SonarQube...
echo.

echo Make sure SonarQube is running at http://localhost:9000
echo.

echo Using curl to check project existence...
echo If curl is not installed, please open http://localhost:9000 in your browser
echo and manually check if project 'pdl' exists.
echo.

echo Token: sqp_ca5888234671bfe3514420a0e8ce3dbedee3782d
echo.

echo Command: curl -u sqp_ca5888234671bfe3514420a0e8ce3dbedee3782d: http://localhost:9000/api/projects/search?projects=pdl
echo.

curl -u sqp_ca5888234671bfe3514420a0e8ce3dbedee3782d: http://localhost:9000/api/projects/search?projects=pdl

echo.
echo.
echo If you see project information above, the project exists.
echo If you see an empty list or error, the project does not exist.
echo.
echo Please visit http://localhost:9000 to:
echo 1. Login with admin/admin
echo 2. Create a new project with key 'pdl'
echo 3. Try scanning again
echo.
pause