@echo off
echo 正在清理缓存文件...

echo 移除已跟踪的node_modules文件夹...
git rm -r --cached backend/node_modules/ 2>nul

echo 移除已跟踪的build文件夹...
git rm -r --cached build/ 2>nul

echo 移除已跟踪的.env文件...
git rm --cached backend/.env 2>nul

echo 移除已跟踪的.env.example文件...
git rm --cached backend/.env.example 2>nul

echo 移除已跟踪的临时测试文件夹...
git rm -r --cached temp_test/ 2>nul

echo 移除已跟踪的文档文件...
git rm --cached "产品需求文档 副本.docx" 2>nul

echo 重新添加所有文件（遵循.gitignore规则）...
git add .

echo 缓存文件清理完成！
echo 现在可以在GitHub Desktop中查看更改，应该只会显示你的代码文件了。
pause
