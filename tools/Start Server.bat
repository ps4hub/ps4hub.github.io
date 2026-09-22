@echo off
title Unelte retea - webserver / porturi
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0WebServer.ps1"
