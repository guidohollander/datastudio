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
  [string[]]$ProcedureNames = @(
    "dbo.UpdateIdentitySnapshot",
    "dbo.GetChangesSinceSnapshot"
  ),

  [Parameter(Mandatory = $false)]
  [switch]$PromptForPassword
)

$ErrorActionPreference = "Stop"

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

if ($Server -eq "localhost,1433" -and $env:SQLSERVER) { $Server = $env:SQLSERVER }
if ($Database -eq "gd_mts" -and $env:SQLDATABASE) { $Database = $env:SQLDATABASE }
if ($User -eq "sa" -and $env:SQLUSER) { $User = $env:SQLUSER }

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
  New-Item -ItemType Directory -Path $ProceduresPath -Force | Out-Null
}

$sqlPassword = Get-PlainPassword

foreach ($proc in $ProcedureNames) {
  $safe = $proc.Replace("[", "").Replace("]", "").Replace(".", "_")
  $outFile = Join-Path $ProceduresPath ("{0}.sql" -f $safe)

  $query = @"
SET NOCOUNT ON;

DECLARE @p sysname = N'$proc';

IF OBJECT_ID(@p, N'P') IS NULL
BEGIN
  RAISERROR('Stored procedure not found: %s', 16, 1, @p);
  RETURN;
END

SELECT sm.definition
FROM sys.sql_modules sm
JOIN sys.objects o ON o.object_id = sm.object_id
WHERE o.object_id = OBJECT_ID(@p);
"@

  Write-Host ("Exporting: {0} -> {1}" -f $proc, $outFile)
  & sqlcmd -S $Server -d $Database -U $User -P $sqlPassword -b -r1 -y 0 -Y 0 -Q $query -o $outFile

  if ($LASTEXITCODE -ne 0) {
    throw "sqlcmd failed exporting: $proc"
  }

  Add-Content -LiteralPath $outFile -Value "`r`nGO`r`n"
}

Write-Host "Done."
