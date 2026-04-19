[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$Server = "localhost,1433",

  [Parameter(Mandatory = $false)]
  [string]$Database = "gd_mts",

  [Parameter(Mandatory = $false)]
  [string]$User = "sa",

  [Parameter(Mandatory = $false)]
  [int]$LoginTimeoutSeconds = 5,

  [Parameter(Mandatory = $false)]
  [int]$QueryTimeoutSeconds = 10
)

$ErrorActionPreference = "Stop"

function Import-DotEnv {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  foreach ($line in (Get-Content -LiteralPath $Path)) {
    $t = $line.Trim()
    if ($t.Length -eq 0) { continue }
    if ($t.StartsWith('#')) { continue }
    $idx = $t.IndexOf('=')
    if ($idx -lt 1) { continue }
    $key = $t.Substring(0,$idx).Trim()
    $val = $t.Substring($idx+1).Trim()
    if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
      $val = $val.Substring(1, $val.Length - 2)
    }
    if (-not [string]::IsNullOrWhiteSpace($key)) {
      Set-Item -Path ("Env:{0}" -f $key) -Value $val -Force
    }
  }
}

Import-DotEnv -Path (Join-Path $PSScriptRoot ".env")

if ($Server -eq "localhost,1433" -and $env:SQLSERVER) { $Server = $env:SQLSERVER }
if ($Database -eq "gd_mts" -and $env:SQLDATABASE) { $Database = $env:SQLDATABASE }
if ($User -eq "sa" -and $env:SQLUSER) { $User = $env:SQLUSER }

if (-not ($env:SQLPASSWORD -and $env:SQLPASSWORD.Trim().Length -gt 0)) {
  throw "SQLPASSWORD is not set. Create .env or set Env:SQLPASSWORD."
}

$sqlPassword = $env:SQLPASSWORD

Write-Host ("Testing dbo.GetChangesSinceSnapshot table-by-table on {0}/{1}" -f $Server, $Database)

# Get all base tables except Snapshot_Hashes and MigrationLog
$tables = & sqlcmd -S $Server -d $Database -U $User -P $sqlPassword -b -r1 -l $LoginTimeoutSeconds -t $QueryTimeoutSeconds -h -1 -W -Q "SET NOCOUNT ON; SELECT TABLE_SCHEMA + '.' + TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' AND TABLE_NAME NOT IN ('Snapshot_Hashes','MigrationLog');"

foreach ($line in $tables) {
  $tn = ($line ?? "").Trim()
  if ([string]::IsNullOrWhiteSpace($tn)) { continue }

  Write-Host ("- {0}" -f $tn)
  $q = "SET NOCOUNT ON; EXEC dbo.GetChangesSinceSnapshot @TableName = N'$tn';"
  & sqlcmd -S $Server -d $Database -U $User -P $sqlPassword -b -r1 -l $LoginTimeoutSeconds -t $QueryTimeoutSeconds -Q $q | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host ("FAILED on {0}" -f $tn)
    exit 1
  }
}

Write-Host "All tables succeeded within timeouts."
