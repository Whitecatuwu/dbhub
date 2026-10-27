# Start Claude Code in the DBHub repo with the project system prompt appended.
# Extra arguments are passed through, e.g.: .\prompts\start-claude.ps1 -p "run the tests"

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$promptFile = Join-Path $PSScriptRoot 'dbhub-system.md'

Set-Location $repoRoot
claude --append-system-prompt-file $promptFile @args
