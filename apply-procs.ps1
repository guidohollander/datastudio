[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$Server = "localhost,1433",

  [Parameter(Mandatory = $false)]
  [string]$Database = "gd_mts",

  [Parameter(Mandatory = $false)]
  [string]$User = "sa",

  [Parameter(Mandatory = $false)]
  [string]$ProceduresPath = (Join-Path $PSScriptRoot "sql\dbo\procedures"),

  [Parameter(Mandatory = $false)]
  [string]$TablesPath = (Join-Path $PSScriptRoot "sql\dbo\tables"),

  [Parameter(Mandatory = $false)]
  [int]$LoginTimeoutSeconds = 5,

  [Parameter(Mandatory = $false)]
  [int]$QueryTimeoutSeconds = 60,

  [Parameter(Mandatory = $false)]
  [switch]$PromptForPassword
)

$ErrorActionPreference = "Stop"

Write-Host "apply-procs.ps1 starting"

function Import-DotEnv {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  $lines = Get-Content -LiteralPath $Path
  foreach ($line in $lines) {
    $t = $line.Trim()
    if ($t.Length -eq 0) { continue }
    if ($t.StartsWith('#')) { continue }
    $idx = $t.IndexOf('=')
    if ($idx -lt 1) { continue }
    $key = $t.Substring(0, $idx).Trim()
    $val = $t.Substring($idx + 1).Trim()
    if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
      $val = $val.Substring(1, $val.Length - 2)
    }
    if (-not [string]::IsNullOrWhiteSpace($key)) {
      Set-Item -Path ("Env:{0}" -f $key) -Value $val -Force
    }
  }
}

Import-DotEnv -Path (Join-Path $PSScriptRoot ".env")

Write-Host ("Loaded .env: {0}" -f (Test-Path -LiteralPath (Join-Path $PSScriptRoot ".env")))

if ($Server -eq "localhost,1433" -and $env:SQLSERVER) { $Server = $env:SQLSERVER }
if ($Database -eq "gd_mts" -and $env:SQLDATABASE) { $Database = $env:SQLDATABASE }
if ($User -eq "sa" -and $env:SQLUSER) { $User = $env:SQLUSER }

Write-Host ("Using Server={0} Database={1} User={2}" -f $Server, $Database, $User)

function Get-PlainPassword {
  if ($env:SQLPASSWORD -and $env:SQLPASSWORD.Trim().Length -gt 0) {
    Write-Host "Using SQLPASSWORD from environment/.env"
    return $env:SQLPASSWORD
  }

  if (-not $PromptForPassword) {
    throw "SQLPASSWORD is not set. Create .env next to this script (or set Env:SQLPASSWORD) or pass -PromptForPassword."
  }

  $secure = Read-Host -AsSecureString "SQL Password for $User@$Server"
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

if (-not (Test-Path -LiteralPath $ProceduresPath)) {
  throw "ProceduresPath does not exist: $ProceduresPath"
}

$sqlPassword = Get-PlainPassword

if (Test-Path -LiteralPath $TablesPath) {
  $tableFiles = Get-ChildItem -LiteralPath $TablesPath -Filter "*.sql" -File | Sort-Object Name
  foreach ($f in $tableFiles) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Write-Host ("Applying table script: {0}" -f $f.FullName)
    Write-Host ("Running sqlcmd (login timeout {0}s, query timeout {1}s)" -f $LoginTimeoutSeconds, $QueryTimeoutSeconds)
    & sqlcmd -S $Server -d $Database -U $User -P $sqlPassword -b -r1 -l $LoginTimeoutSeconds -t $QueryTimeoutSeconds -i $f.FullName
    if ($LASTEXITCODE -ne 0) {
      throw "sqlcmd failed on file: $($f.FullName)"
    }
    $sw.Stop()
    Write-Host ("Applied in {0} ms" -f $sw.ElapsedMilliseconds)
  }
}

$files = Get-ChildItem -LiteralPath $ProceduresPath -Filter "dbo_*.sql" -File | Sort-Object Name
if ($files.Count -eq 0) {
  throw "No .sql files found under $ProceduresPath"
}

foreach ($f in $files) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  Write-Host ("Applying: {0}" -f $f.FullName)

  Write-Host ("Running sqlcmd (login timeout {0}s, query timeout {1}s)" -f $LoginTimeoutSeconds, $QueryTimeoutSeconds)
  & sqlcmd -S $Server -d $Database -U $User -P $sqlPassword -b -r1 -l $LoginTimeoutSeconds -t $QueryTimeoutSeconds -i $f.FullName
  if ($LASTEXITCODE -ne 0) {
    throw "sqlcmd failed on file: $($f.FullName)"
  }

  $sw.Stop()
  Write-Host ("Applied in {0} ms" -f $sw.ElapsedMilliseconds)
}

Write-Host "Done."
