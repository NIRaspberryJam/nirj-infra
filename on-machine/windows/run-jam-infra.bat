:: run-jam-infra.bat
@echo off
powershell -ExecutionPolicy Bypass -File "C:\Scripts\check-meshagent.ps1"
powershell -ExecutionPolicy Bypass -File "C:\Scripts\gitops-check.ps1"