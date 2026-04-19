#!/usr/bin/env pwsh
# Fix generator expressions for nvarchar lookup fields that need numeric values for replay

$ErrorActionPreference = "Stop"

function Import-DotEnv {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $lines = Get-Content -LiteralPath $Path
  foreach ($line in $lines) {
    $t = $line.Trim()
    if ($t.Length -eq 0 -or $t.StartsWith('#')) { continue }
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

$serverName = if ($env:SQLSERVER) { $env:SQLSERVER } else { "localhost,1433" }
$databaseName = if ($env:SQLDATABASE) { $env:SQLDATABASE } else { "gd_mts" }
$username = if ($env:SQLUSER) { $env:SQLUSER } else { "sa" }
$password = $env:SQLPASSWORD

if (-not $password) {
    throw "SQLPASSWORD not found in .env file"
}

$sqlScript = @"
-- Fix generator expressions for nvarchar fields that store numeric lookup values
-- These fields are nvarchar in source but bigint in target, so we need numeric generators

-- Update COUNTRYOFBIRTH to use lookup for numeric values (even though column is nvarchar)
UPDATE f
SET f.Notes = 'gen: lookup(COUNTRY)'
FROM dbo.MigrationDomainField f
WHERE f.ObjectKey = 'captured_data'
  AND UPPER(f.PhysicalColumn) = 'COUNTRYOFBIRTH';

PRINT 'Updated COUNTRYOFBIRTH: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- Update HOMEADDRESSCOUNTRY to use lookup for numeric values
UPDATE f
SET f.Notes = 'gen: lookup(COUNTRY)'
FROM dbo.MigrationDomainField f
WHERE f.ObjectKey = 'captured_data'
  AND UPPER(f.PhysicalColumn) = 'HOMEADDRESSCOUNTRY';

PRINT 'Updated HOMEADDRESSCOUNTRY: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- Update HOMEADDRESSREGION to use random numeric values
UPDATE f
SET f.Notes = 'gen: random(1, 12)'
FROM dbo.MigrationDomainField f
WHERE f.ObjectKey = 'captured_data'
  AND UPPER(f.PhysicalColumn) = 'HOMEADDRESSREGION';

PRINT 'Updated HOMEADDRESSREGION: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- Update HOMEADDRESSSTREET to use random numeric values
UPDATE f
SET f.Notes = 'gen: random(1, 100)'
FROM dbo.MigrationDomainField f
WHERE f.ObjectKey = 'captured_data'
  AND UPPER(f.PhysicalColumn) = 'HOMEADDRESSSTREET';

PRINT 'Updated HOMEADDRESSSTREET: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- Show updated fields
SELECT 
    f.ObjectKey,
    c.PhysicalTable,
    f.PhysicalColumn,
    f.DataType,
    f.Notes AS GeneratorExpression
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
WHERE f.ObjectKey = 'captured_data'
  AND UPPER(f.PhysicalColumn) IN ('COUNTRYOFBIRTH', 'HOMEADDRESSCOUNTRY', 'HOMEADDRESSREGION', 'HOMEADDRESSSTREET', 'NATIONALITY')
ORDER BY c.PhysicalTable, f.PhysicalColumn;
"@

Write-Host "Fixing generator expressions for nvarchar lookup fields..." -ForegroundColor Cyan

$tempFile = [System.IO.Path]::GetTempFileName()
$sqlScript | Out-File -FilePath $tempFile -Encoding UTF8

try {
    $result = sqlcmd -S $serverName -d $databaseName -U $username -P $password -b -r1 -i $tempFile -W 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully updated generator expressions!" -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Host "Error updating generators:" -ForegroundColor Red
        Write-Host $result
    }
} finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}
