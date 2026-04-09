@echo off
echo Opening all 10 platform files in VS Code for side-by-side comparison...
"C:\Users\%USERNAME%\AppData\Local\Programs\Microsoft VS Code\Code.exe" ^
  "F:\study\hosting\WebHosting\comparison\CLOUDFLARE-PAGES.md" ^
  "F:\study\hosting\WebHosting\comparison\VERCEL.md" ^
  "F:\study\hosting\WebHosting\comparison\NETLIFY.md" ^
  "F:\study\hosting\WebHosting\comparison\AWS-AMPLIFY.md" ^
  "F:\study\hosting\WebHosting\comparison\FIREBASE-HOSTING.md" ^
  "F:\study\hosting\WebHosting\comparison\AZURE-STATIC-WEB-APPS.md" ^
  "F:\study\hosting\WebHosting\comparison\RENDER.md" ^
  "F:\study\hosting\WebHosting\comparison\GITHUB-PAGES.md" ^
  "F:\study\hosting\WebHosting\comparison\GITLAB-PAGES.md" ^
  "F:\study\hosting\WebHosting\comparison\SURGE-SH.md"
echo.
echo VS Code opened with all 10 files!
echo.
echo To view all 10 files side-by-side:
echo 1. Click View menu
echo 2. Click Editor Layout 
echo 3. Choose "Grid (2x2)" or custom layout
echo 4. Drag each tab to a different grid cell
echo 5. Or use Ctrl+\ to split editors
echo.
pause