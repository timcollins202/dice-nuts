@echo off
@setlocal enabledelayedexpansion

:: Generate a timestamp (YYYYMMDD_HHMMSS)
for /f "tokens=2 delims==" %%I in ('"wmic os get localdatetime /value"') do set dt=%%I
set timestamp=%dt:~0,8%_%dt:~8,6%

:: Rename existing dice-nuts.nes if it exists
if exist output\dice-nuts.nes (
    rename output\dice-nuts.nes dice-nuts_%timestamp%.nes
)

@del output\dice-nuts.o
@del output\dice-nuts.map.txt
@del output\dice-nuts.labels.txt
@del output\dice-nuts.nes.ram.nl
@del output\dice-nuts.nes.0.nl
@del output\dice-nuts.nes.1.nl
@del output\dice-nuts.nes.dbg

@echo.
@echo Compiling...
\cc65\bin\ca65 dice-nuts.asm -g -o output\dice-nuts.o
@IF ERRORLEVEL 1 GOTO failure
@echo.
@echo Linking...
\cc65\bin\ld65 -o output\dice-nuts.nes -C dice-nuts.cfg output\dice-nuts.o -m output\dice-nuts.map.txt -Ln output\dice-nuts.labels.txt --dbgfile output\dice-nuts.nes.dbg
@IF ERRORLEVEL 1 GOTO failure

@echo.
@echo Success. Previous version saved as dice-nuts_%timestamp%.nes
@GOTO endbuild

:failure
@echo.
@echo Build error!
:endbuild
@endlocal
