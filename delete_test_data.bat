@echo off
echo Deleting test data...
cd backend
node delete_test_data.js
cd ..
echo Done.
pause
