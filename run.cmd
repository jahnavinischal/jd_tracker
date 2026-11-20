@echo off
REM Entrypoint for Windows Task Scheduler.
REM Set the task's "Start in" field to this folder, or rely on the cd below.

cd /d "%~dp0"

if not exist logs mkdir logs

REM Optional: keep secrets out of the global environment by setting them here.
REM set TELEGRAM_BOT_TOKEN=...
REM set TELEGRAM_CHAT_ID=...

uv run python -m tracker.run %* >> "logs\run.log" 2>&1
exit /b %ERRORLEVEL%
