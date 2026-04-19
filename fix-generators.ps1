#!/usr/bin/env pwsh
# Fix generator expressions for lookup fields

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
-- Fix generator expressions for lookup fields that are currently using string pools

-- Update COUNTRYOFBIRTH to use lookup(COUNTRY) for bigint columns
UPDATE f
SET f.Notes = 'gen: lookup(COUNTRY)'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
INNER JOIN dbo.DataDictionaryColumn dc ON dc.TableObjectId = OBJECT_ID(c.PhysicalTable) AND dc.ColumnName = f.PhysicalColumn
WHERE UPPER(f.PhysicalColumn) = 'COUNTRYOFBIRTH'
  AND dc.TypeName IN ('bigint', 'int')
  AND (f.Notes LIKE '%pool(countries%' OR f.Notes IS NULL OR f.Notes = '');

PRINT 'Updated COUNTRYOFBIRTH fields: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- Update HOMEADDRESSCOUNTRY to use lookup(COUNTRY) for bigint columns
UPDATE f
SET f.Notes = 'gen: lookup(COUNTRY)'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
INNER JOIN dbo.DataDictionaryColumn dc ON dc.TableObjectId = OBJECT_ID(c.PhysicalTable) AND dc.ColumnName = f.PhysicalColumn
WHERE UPPER(f.PhysicalColumn) = 'HOMEADDRESSCOUNTRY'
  AND dc.TypeName IN ('bigint', 'int')
  AND (f.Notes LIKE '%pool(countries%' OR f.Notes IS NULL OR f.Notes = '');

PRINT 'Updated HOMEADDRESSCOUNTRY fields: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- Update HOMEADDRESSREGION to use random(1, 12) for bigint columns
UPDATE f
SET f.Notes = 'gen: random(1, 12)'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
INNER JOIN dbo.DataDictionaryColumn dc ON dc.TableObjectId = OBJECT_ID(c.PhysicalTable) AND dc.ColumnName = f.PhysicalColumn
WHERE UPPER(f.PhysicalColumn) = 'HOMEADDRESSREGION'
  AND dc.TypeName IN ('bigint', 'int');

PRINT 'Updated HOMEADDRESSREGION fields: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- Update HOMEADDRESSSTREET to use random(1, 100) for bigint columns
UPDATE f
SET f.Notes = 'gen: random(1, 100)'
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
INNER JOIN dbo.DataDictionaryColumn dc ON dc.TableObjectId = OBJECT_ID(c.PhysicalTable) AND dc.ColumnName = f.PhysicalColumn
WHERE UPPER(f.PhysicalColumn) = 'HOMEADDRESSSTREET'
  AND dc.TypeName IN ('bigint', 'int');

PRINT 'Updated HOMEADDRESSSTREET fields: ' + CAST(@@ROWCOUNT AS NVARCHAR(10));

-- Show updated fields
SELECT 
    f.ObjectKey,
    c.PhysicalTable,
    f.PhysicalColumn,
    dc.TypeName,
    f.Notes AS GeneratorExpression
FROM dbo.MigrationDomainField f
INNER JOIN dbo.MigrationDomainComponent c ON c.ObjectKey = f.ObjectKey AND c.ComponentKey = f.ComponentKey
INNER JOIN dbo.DataDictionaryColumn dc ON dc.TableObjectId = OBJECT_ID(c.PhysicalTable) AND dc.ColumnName = f.PhysicalColumn
WHERE UPPER(f.PhysicalColumn) IN ('COUNTRYOFBIRTH', 'HOMEADDRESSCOUNTRY', 'HOMEADDRESSREGION', 'HOMEADDRESSSTREET')
ORDER BY c.PhysicalTable, f.PhysicalColumn;
"@

Write-Host "Fixing generator expressions for lookup fields..." -ForegroundColor Cyan

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
