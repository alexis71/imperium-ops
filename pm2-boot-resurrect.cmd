@echo off
REM ============================================================
REM  pm2-boot-resurrect.cmd  -  Imperium  -  N68 (2026-05-20)
REM  Restaura el stack pm2 al arrancar Windows.
REM  Llamado por la tarea programada "PM2-Resurrect".
REM
REM  Robusto ante migracion de Node.js: fija el PATH a nvm4w
REM  + el prefijo global de npm antes de invocar pm2, asi no
REM  depende de la resolucion de PATH del entorno de la tarea.
REM  Si node se vuelve a mover, editar solo la linea de abajo.
REM ============================================================
set PATH=C:\nvm4w\nodejs;C:\Users\Administrator\AppData\Roaming\npm;%PATH%
pm2 resurrect
