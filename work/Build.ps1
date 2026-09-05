param([string]$OutputDirectory = (Join-Path $PSScriptRoot '..\outputs'))
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    foreach ($source in Get-ChildItem -LiteralPath 'EncounterLab' -Filter '*.lua' -Recurse) {
        & luac -p $source.FullName
        if ($LASTEXITCODE -ne 0) { throw "Lua syntax: $($source.Name)" }
    }
    & lua 'tests\simulation_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Simulation tests failed' }
    Push-Location 'tests'
    try {
        & lua 'persistence_test.lua'
        if ($LASTEXITCODE -ne 0) { throw 'Persistence tests failed' }
    } finally { Pop-Location }
    & lua 'tests\sentinels_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Sentinels tests failed' }
    & lua 'tests\sentinels_renderer_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Sentinels renderer tests failed' }
    & lua 'tests\sszorak_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Sszorak rehearsal tests failed' }
    & lua 'tests\tempest_renderer_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Tempest renderer tests failed' }
    & lua 'tests\integration_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Integration tests failed' }
    & lua 'tests\input_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Input tests failed' }
    & lua 'tests\mouse_capture_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Mouse capture tests failed' }
    & lua 'tests\view_motion_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'View motion tests failed' }
    & lua 'tests\view_motion_cadence_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'View motion cadence tests failed' }
    & lua 'tests\mouse_trace_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Mouse trace tests failed' }
    & lua 'tests\scene_assets_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Native scene tests failed' }
    & lua 'tests\sentinels_arena_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Sentinels arena projection tests failed' }
    & lua 'tests\localization_test.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Localization tests failed' }
    & lua 'renderer-tests.lua'
    if ($LASTEXITCODE -ne 0) { throw 'Renderer tests failed' }
    & python 'package.py' $OutputDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Package validation failed' }
} finally { Pop-Location }
