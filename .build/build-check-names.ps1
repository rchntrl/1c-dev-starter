param(
    [Parameter(Position = 0)]
    [string]$Processing = ''
)

# Проверяет имена переменных в модулях внешней обработки (правило .claude/rules/external-variable-names.md):
# - во всех модулях: имена не совпадают со свойствами глобального контекста (Документы, Перечисления и т. п.);
# - в модуле объекта: имена не совпадают с реквизитами и табличными частями обработки.
# Код выхода 1, если найдены ошибки.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'build-auth.ps1')

if ([string]::IsNullOrWhiteSpace($Processing)) {
    $parametersFile = Join-Path $PSScriptRoot 'parameters.yml'
    if (Test-Path -LiteralPath $parametersFile) {
        $Processing = (Read-BuildParameters -Path $parametersFile)['external']
    }
}
if ([string]::IsNullOrWhiteSpace($Processing)) {
    Write-Host '[ERROR] External processing name is required: build-check-names.ps1 <name>'
    exit 1
}

$sourceXml = Join-Path $root "external\$Processing.xml"
$sourceDir = Join-Path $root "external\$Processing"
if (-not (Test-Path -LiteralPath $sourceXml)) {
    Write-Host "[ERROR] Not found: $sourceXml"
    exit 1
}

$md = 'http://v8.1c.ru/8.3/MDClasses'

function Get-ChildNames([xml]$Document, [string]$ObjectPath, [string[]]$Kinds) {
    $ns = New-Object System.Xml.XmlNamespaceManager($Document.NameTable)
    $ns.AddNamespace('md', $md)
    $names = @()
    foreach ($kind in $Kinds) {
        foreach ($node in $Document.SelectNodes("$ObjectPath/md:ChildObjects/md:$kind", $ns)) {
            $name = $node.SelectSingleNode('md:Properties/md:Name', $ns)
            $names += if ($name) { $name.InnerText } else { $node.InnerText }
        }
    }
    return $names
}

# Реквизиты и табличные части обработки.
[xml]$processingXml = Get-Content -LiteralPath $sourceXml -Raw -Encoding UTF8
$ownNames = @{}
foreach ($name in (Get-ChildNames $processingXml '/md:MetaDataObject/md:ExternalDataProcessor' @('Attribute', 'TabularSection'))) {
    $ownNames[$name.ToLower()] = $name
}

# Свойства глобального контекста, которые чаще всего пытаются использовать как переменные.
$globalNames = @{}
@(
    'Документы', 'Справочники', 'Константы', 'Перечисления', 'Отчеты', 'Обработки', 'ВнешниеОтчеты',
    'ВнешниеОбработки', 'ВнешниеИсточникиДанных', 'РегистрыСведений', 'РегистрыНакопления', 'РегистрыБухгалтерии',
    'РегистрыРасчета', 'ПланыОбмена', 'ПланыВидовХарактеристик', 'ПланыСчетов', 'ПланыВидовРасчета',
    'БизнесПроцессы', 'Задачи', 'ЖурналыДокументов', 'Последовательности', 'ПараметрыСеанса', 'Метаданные',
    'ПользователиИнформационнойБазы', 'ХранилищаНастроек', 'ХранилищеОбщихНастроек', 'ХранилищеСистемныхНастроек',
    'ХранилищеВариантовОтчетов', 'ХранилищеНастроекДанныхФорм', 'ХранилищеПользовательскихНастроекОтчетов',
    'РегламентныеЗадания', 'ФоновыеЗадания', 'БиблиотекаКартинок', 'БиблиотекаСтилей', 'WSСсылки',
    'Символы', 'ПараметрЗапуска', 'ЭтотОбъект', 'ЭтаФорма'
) | ForEach-Object { $globalNames[$_.ToLower()] = "свойство глобального контекста $_" }

# Имена, которые вводит модуль: параметры, Перем, переменные циклов, левые части присваиваний.
function Get-DeclaredNames([string]$Path) {
    $result = @()
    $lineNumber = 0
    foreach ($rawLine in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        $lineNumber++
        $line = $rawLine -replace '"[^"]*"', '""'
        $line = ($line -split '//', 2)[0]
        if ($line -match '^\s*\|') { continue }

        if ($line -match '^\s*(?:Процедура|Функция|Procedure|Function)\s+[\w]+\s*\((.*)\)') {
            foreach ($parameter in ($Matches[1] -split ',')) {
                $parameterName = ($parameter -replace '^\s*(?:Знач|Val)\s+', '' -split '=')[0].Trim()
                if ($parameterName) { $result += [pscustomobject]@{ Name = $parameterName; Line = $lineNumber; Kind = 'параметр' } }
            }
        } elseif ($line -match '^\s*(?:Перем|Var)\s+(.+?);') {
            foreach ($variable in ($Matches[1] -split ',')) {
                $variableName = ($variable.Trim() -split '\s')[0]
                if ($variableName) { $result += [pscustomobject]@{ Name = $variableName; Line = $lineNumber; Kind = 'Перем' } }
            }
        } elseif ($line -match '^\s*(?:Для\s+Каждого|For\s+Each)\s+([\w]+)\s+(?:Из|In)\b') {
            $result += [pscustomobject]@{ Name = $Matches[1]; Line = $lineNumber; Kind = 'переменная цикла' }
        } elseif ($line -match '^\s*(?:Для|For)\s+([\w]+)\s*=') {
            $result += [pscustomobject]@{ Name = $Matches[1]; Line = $lineNumber; Kind = 'переменная цикла' }
        } elseif ($line -match '^\s*([\w]+)\s*=') {
            $result += [pscustomobject]@{ Name = $Matches[1]; Line = $lineNumber; Kind = 'присваивание' }
        }
    }
    return $result
}

$errors = 0
$warnings = 0
foreach ($module in (Get-ChildItem -LiteralPath $sourceDir -Recurse -Filter '*.bsl')) {
    $relative = $module.FullName.Substring($root.Length + 1)
    $isObjectModule = $module.Name -eq 'ObjectModule.bsl'
    foreach ($declared in (Get-DeclaredNames $module.FullName)) {
        $key = $declared.Name.ToLower()
        if ($globalNames.ContainsKey($key)) {
            Write-Host "[ERROR] ${relative}:$($declared.Line): $($declared.Kind) $($declared.Name) совпадает: $($globalNames[$key])"
            $errors++
        } elseif ($isObjectModule -and $ownNames.ContainsKey($key)) {
            if ($declared.Kind -eq 'присваивание') {
                Write-Host "[WARN]  ${relative}:$($declared.Line): присваивание реквизиту обработки $($declared.Name) — проверьте, что это намеренная запись в реквизит, а не локальная переменная"
                $warnings++
            } else {
                Write-Host "[ERROR] ${relative}:$($declared.Line): $($declared.Kind) $($declared.Name) совпадает с реквизитом или табличной частью обработки"
                $errors++
            }
        }
    }
}

Write-Host "Checked $Processing`: errors $errors, warnings $warnings."
if ($errors -gt 0) { exit 1 }
