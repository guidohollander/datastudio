# Satisfaction Gate Script
# Asks user if they are satisfied with the implementation
# Auto-answers "no" if test failures are detected in myway.txt

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mywayPath = Join-Path $scriptDir "myway.txt"
$mywayContent = Get-Content $mywayPath -Raw -ErrorAction SilentlyContinue

# Check for test failure markers in myway.txt
$hasTestFailures = $mywayContent -match "(?i)(FAILED TESTS|TEST FAILURES|playwright.*failed)"

if ($hasTestFailures) {
    Write-Host "⚠️  Test failures detected in myway.txt - auto-continuing workflow" -ForegroundColor Yellow
    $response = 'n'
} else {
    Write-Host "Are you satisfied? (y/n): " -NoNewline -ForegroundColor Cyan
    $response = Read-Host
}

if ($response -eq 'n' -or $response -eq 'N') {
    Write-Host ""
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $mywayPath = Join-Path $scriptDir "myway.txt"
    $templatePath = Join-Path $scriptDir "myway-template.txt"
    
    # Check if myway.txt starts with "new request"
    $mywayContent = Get-Content $mywayPath -Raw
    $currentRequestPath = Join-Path $scriptDir "current-request.md"
    
    if ($mywayContent -match "^\s*new request") {
        Write-Host "Detected 'new request' - clearing current-request.md..." -ForegroundColor Cyan
        
        # Create blank template for current-request.md
        $blankTemplate = @"
# Current Request

**Status:** Pending  
**Created:** $(Get-Date -Format 'yyyy-MM-dd')  
**Last Updated:** $(Get-Date -Format 'yyyy-MM-dd')

---

## Feature Description

[This will be filled in during PHASE 1]

---

## Functional Requirements

[Requirements will be defined during PHASE 1]

---

## Acceptance Criteria

[Criteria will be defined during PHASE 1]
"@
        
        $blankTemplate | Out-File -FilePath $currentRequestPath -Encoding UTF8 -Force
        Write-Host "Blank template applied to current-request.md" -ForegroundColor Green
    }
    
    Write-Host "=== Contents of myway.txt, cascade SHOULD use the development workflow as defined in the implement workflow ===" -ForegroundColor Yellow
    Write-Host ""
    Get-Content $mywayPath
    Write-Host ""
    Write-Host "Cascade will now process your request from myway.txt and always use the development workflow as defined in the implement workflow" -ForegroundColor Cyan
}
elseif ($response -eq 'y' -or $response -eq 'Y') {
    Write-Host "Great! Task completed successfully." -ForegroundColor Green
    
    # Run tests and generate report automatically
    Write-Host "`nRunning automated tests..." -ForegroundColor Yellow
    Write-Host "Tests will run in headless mode first, then headed mode if failures occur." -ForegroundColor Gray
    
    & "..\scripts\test-and-report.ps1"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ All tests passed! Implementation verified." -ForegroundColor Green
        Write-Host "Results have been added to myway.txt" -ForegroundColor Cyan
    } else {
        Write-Host "`n⚠️  Some tests failed." -ForegroundColor Yellow
        Write-Host "Detailed failure analysis has been added to myway.txt" -ForegroundColor Cyan
        Write-Host "Run satisfied.ps1 again to see the failures and continue." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Please answer with 'y' or 'n'" -ForegroundColor Red
}
