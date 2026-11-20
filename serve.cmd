@echo off
REM Open the dashboard in a browser, served from the live database.
REM Leave this window open while you use the page; Ctrl+C stops it.

cd /d "%~dp0"
uv run python -m tracker.web %*
