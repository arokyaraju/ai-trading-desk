@echo off
echo ========================================================
echo   AI TRADING DESK - PRIVATE CLOUD DEPLOYMENT HELPER
echo ========================================================
echo.
echo 1. Verifying Git status...
git status -s
echo.
echo 2. Staging AI Trading Desk files...
git add ai_trading_desk render.yaml
git commit -m "Deploy AI Trading Desk with 11-Agent Architecture, PostgreSQL, and Web Dashboard"
echo.
echo 3. Ready to push to your private GitHub repository:
echo    Run: git push origin main
echo.
echo 4. Next on Render.com:
echo    - Open https://dashboard.render.com
echo    - Click 'New' -> 'Blueprint'
echo    - Connect your private repository
echo    - Render will auto-provision PostgreSQL and launch the web service!
echo ========================================================
pause
