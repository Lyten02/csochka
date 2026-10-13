[CmdletBinding()]
param(
    [ValidateSet('orchestrator', 'astra', 'sol')]
    [string]$Role = 'orchestrator',
    [ValidateSet('medium', 'high', 'xhigh', 'max')]
    [string]$Thinking
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$models = @{
    orchestrator = 'anthropic/claude-opus-5-5'
    astra = 'openai-codex/gpt-6-astra'
    sol = 'openai-codex/gpt-6-sol'
}
if (-not $Thinking) {
    $Thinking = if ($Role -eq 'orchestrator') { 'high' } else { 'medium' }
}
$ompCommand = (Get-Command omp -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
Push-Location -LiteralPath $projectRoot
try {
    & $ompCommand --cwd $projectRoot --config (Join-Path $projectRoot '.omp/config.yml') `
        --model $models[$Role] --thinking $Thinking --no-prewalk
    $ompExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $ompExitCode
