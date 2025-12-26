@echo off
echo Adding test data...
cd backend
node generate_test_data.js
cd ..
echo Done.
pause
