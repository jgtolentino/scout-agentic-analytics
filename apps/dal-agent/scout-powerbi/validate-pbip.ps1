# Scout Power BI PBIP Validation Script
# Validates PBIP/TMDL structure and syntax

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = ".",
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

Write-Host "Scout Power BI Validation Script" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

$ErrorCount = 0
$WarningCount = 0

function Write-ValidationResult {
    param($Message, $Type = "Info", $Details = "")

    switch ($Type) {
        "Error" {
            Write-Host "❌ $Message" -ForegroundColor Red
            if ($Details) { Write-Host "   $Details" -ForegroundColor Gray }
            $script:ErrorCount++
        }
        "Warning" {
            Write-Host "⚠️  $Message" -ForegroundColor Yellow
            if ($Details) { Write-Host "   $Details" -ForegroundColor Gray }
            $script:WarningCount++
        }
        "Success" {
            Write-Host "✅ $Message" -ForegroundColor Green
            if ($Verbose -and $Details) { Write-Host "   $Details" -ForegroundColor Gray }
        }
        default {
            Write-Host "ℹ️  $Message" -ForegroundColor Blue
            if ($Details) { Write-Host "   $Details" -ForegroundColor Gray }
        }
    }
}

# 1. Validate Directory Structure
Write-Host "`n1. Validating Directory Structure..." -ForegroundColor Cyan

$RequiredDirs = @(
    "pbip-model-core",
    "pbip-model-core/.pbip",
    "pbip-model-core/model",
    "pbip-model-core/model/tables",
    "executive-dashboard",
    "sales-analysis",
    "store-performance",
    "category-insights",
    "predictive-analytics"
)

foreach ($dir in $RequiredDirs) {
    $fullPath = Join-Path $ProjectPath $dir
    if (Test-Path $fullPath) {
        Write-ValidationResult "Directory exists: $dir" "Success"
    } else {
        Write-ValidationResult "Missing directory: $dir" "Error"
    }
}

# 2. Validate Core Model Files
Write-Host "`n2. Validating Core Model Files..." -ForegroundColor Cyan

$CoreFiles = @(
    "pbip-model-core/.pbip/definition.pbir",
    "pbip-model-core/model/Model.tmdl",
    "pbip-model-core/model/datasources.tmdl",
    "pbip-model-core/model/relationships.tmdl",
    "pbip-model-core/model/measures.tmdl",
    "pbip-model-core/model/roles.tmdl",
    "pbip-model-core/model/refresh-policy.tmdl"
)

foreach ($file in $CoreFiles) {
    $fullPath = Join-Path $ProjectPath $file
    if (Test-Path $fullPath) {
        Write-ValidationResult "Core file exists: $file" "Success"

        # Basic syntax validation
        try {
            $content = Get-Content $fullPath -Raw
            if ($file.EndsWith(".pbir")) {
                $json = ConvertFrom-Json $content
                Write-ValidationResult "Valid JSON syntax: $file" "Success"
            } elseif ($file.EndsWith(".tmdl")) {
                if ($content.Contains("table ") -or $content.Contains("model ") -or $content.Contains("dataSource ") -or $content.Contains("relationship ") -or $content.Contains("measure ") -or $content.Contains("role ") -or $content.Contains("refreshPolicy ")) {
                    Write-ValidationResult "Valid TMDL syntax: $file" "Success"
                } else {
                    Write-ValidationResult "Invalid TMDL syntax: $file" "Warning" "Missing expected TMDL keywords"
                }
            }
        } catch {
            Write-ValidationResult "Syntax error in: $file" "Error" $_.Exception.Message
        }
    } else {
        Write-ValidationResult "Missing core file: $file" "Error"
    }
}

# 3. Validate Table Definitions
Write-Host "`n3. Validating Table Definitions..." -ForegroundColor Cyan

$TableFiles = @(
    "pbip-model-core/model/tables/dim_date.tmdl",
    "pbip-model-core/model/tables/dim_store.tmdl",
    "pbip-model-core/model/tables/dim_brand.tmdl",
    "pbip-model-core/model/tables/dim_category.tmdl",
    "pbip-model-core/model/tables/mart_tx.tmdl",
    "pbip-model-core/model/tables/platinum_predictions.tmdl"
)

foreach ($file in $TableFiles) {
    $fullPath = Join-Path $ProjectPath $file
    if (Test-Path $fullPath) {
        $content = Get-Content $fullPath -Raw
        $tableName = (Split-Path $file -Leaf).Replace(".tmdl", "")

        if ($content.Contains("table `"$tableName`"")) {
            Write-ValidationResult "Valid table definition: $tableName" "Success"
        } else {
            Write-ValidationResult "Table name mismatch: $tableName" "Warning" "Table definition doesn't match filename"
        }

        # Check for required elements
        if ($content.Contains("partition ") -and $content.Contains("column ")) {
            Write-ValidationResult "Complete table structure: $tableName" "Success"
        } else {
            Write-ValidationResult "Incomplete table structure: $tableName" "Warning" "Missing partition or columns"
        }
    } else {
        Write-ValidationResult "Missing table file: $file" "Error"
    }
}

# 4. Validate Report Templates
Write-Host "`n4. Validating Report Templates..." -ForegroundColor Cyan

$ReportDirs = @("executive-dashboard", "sales-analysis", "store-performance", "category-insights", "predictive-analytics")

foreach ($reportDir in $ReportDirs) {
    $definitionPath = Join-Path $ProjectPath "$reportDir/.pbip/definition.pbir"

    if (Test-Path $definitionPath) {
        try {
            $definition = Get-Content $definitionPath -Raw | ConvertFrom-Json

            if ($definition.artifactKind -eq "report") {
                Write-ValidationResult "Valid report definition: $reportDir" "Success"
            } else {
                Write-ValidationResult "Invalid artifact kind: $reportDir" "Error" "Expected 'report'"
            }

            if ($definition.datasetReference.byPath -eq "../pbip-model-core") {
                Write-ValidationResult "Correct dataset reference: $reportDir" "Success"
            } else {
                Write-ValidationResult "Invalid dataset reference: $reportDir" "Error" "Should reference ../pbip-model-core"
            }
        } catch {
            Write-ValidationResult "Invalid JSON in: $reportDir" "Error" $_.Exception.Message
        }
    } else {
        Write-ValidationResult "Missing report definition: $reportDir" "Error"
    }
}

# 5. Validate Theme
Write-Host "`n5. Validating Theme..." -ForegroundColor Cyan

$themePath = Join-Path $ProjectPath "scout-theme.json"
if (Test-Path $themePath) {
    try {
        $theme = Get-Content $themePath -Raw | ConvertFrom-Json

        if ($theme.name -and $theme.colors -and $theme.palette) {
            Write-ValidationResult "Valid theme structure" "Success"
        } else {
            Write-ValidationResult "Incomplete theme structure" "Warning" "Missing required sections"
        }

        # Check for Philippine localization
        if ($theme.formatting.currency.symbol -eq "₱") {
            Write-ValidationResult "Correct currency symbol (₱)" "Success"
        } else {
            Write-ValidationResult "Incorrect currency symbol" "Warning" "Should use ₱ for Philippines"
        }
    } catch {
        Write-ValidationResult "Invalid theme JSON" "Error" $_.Exception.Message
    }
} else {
    Write-ValidationResult "Missing theme file" "Error"
}

# 6. Validate DAX Measures
Write-Host "`n6. Validating DAX Measures..." -ForegroundColor Cyan

$measuresPath = Join-Path $ProjectPath "pbip-model-core/model/measures.tmdl"
if (Test-Path $measuresPath) {
    $content = Get-Content $measuresPath -Raw
    $measureCount = ([regex]::Matches($content, "measure `"")).Count

    if ($measureCount -ge 60) {
        Write-ValidationResult "Sufficient DAX measures: $measureCount" "Success"
    } else {
        Write-ValidationResult "Insufficient DAX measures: $measureCount" "Warning" "Target is 60+ measures"
    }

    # Check for key measures
    $keyMeasures = @("Total Sales", "Gross Margin %", "Sales YoY Growth", "Prediction Accuracy")
    foreach ($measure in $keyMeasures) {
        if ($content.Contains("measure `"$measure`"")) {
            Write-ValidationResult "Key measure exists: $measure" "Success"
        } else {
            Write-ValidationResult "Missing key measure: $measure" "Warning"
        }
    }
} else {
    Write-ValidationResult "Missing measures file" "Error"
}

# 7. Validate RLS Roles
Write-Host "`n7. Validating RLS Roles..." -ForegroundColor Cyan

$rolesPath = Join-Path $ProjectPath "pbip-model-core/model/roles.tmdl"
if (Test-Path $rolesPath) {
    $content = Get-Content $rolesPath -Raw
    $roleCount = ([regex]::Matches($content, "role `"")).Count

    if ($roleCount -ge 5) {
        Write-ValidationResult "Sufficient RLS roles: $roleCount" "Success"
    } else {
        Write-ValidationResult "Insufficient RLS roles: $roleCount" "Warning" "Recommend 5+ roles"
    }

    # Check for regional roles
    $regionalRoles = @("Regional Manager - NCR", "Store Manager", "Category Manager")
    foreach ($role in $regionalRoles) {
        if ($content.Contains("role `"$role`"")) {
            Write-ValidationResult "Regional role exists: $role" "Success"
        } else {
            Write-ValidationResult "Missing regional role: $role" "Warning"
        }
    }
} else {
    Write-ValidationResult "Missing roles file" "Error"
}

# Summary
Write-Host "`n" + "="*50 -ForegroundColor Green
Write-Host "VALIDATION SUMMARY" -ForegroundColor Green
Write-Host "="*50 -ForegroundColor Green

if ($ErrorCount -eq 0 -and $WarningCount -eq 0) {
    Write-Host "🎉 All validations passed!" -ForegroundColor Green
} elseif ($ErrorCount -eq 0) {
    Write-Host "✅ No errors found, but $WarningCount warning(s) to review" -ForegroundColor Yellow
} else {
    Write-Host "❌ Found $ErrorCount error(s) and $WarningCount warning(s)" -ForegroundColor Red
}

Write-Host "Errors: $ErrorCount" -ForegroundColor $(if ($ErrorCount -eq 0) { "Green" } else { "Red" })
Write-Host "Warnings: $WarningCount" -ForegroundColor $(if ($WarningCount -eq 0) { "Green" } else { "Yellow" })

# Exit with appropriate code
if ($ErrorCount -gt 0) {
    exit 1
} else {
    exit 0
}