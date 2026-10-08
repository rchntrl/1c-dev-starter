$ErrorActionPreference = "Stop"

$oneScript = Get-Command oscript -ErrorAction SilentlyContinue
if (-not $oneScript) {
	throw "OneScript (oscript) was not found in PATH."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $PSScriptRoot "ВосстановлениеКодаМаркировки.bsl"
$source = [System.IO.File]::ReadAllText($sourcePath)

$testCases = @(
	[pscustomobject]@{
		Name = "AI 92 inside the serial number"
		Input = "0108684685809657215Kx(fy91EE1192wYwa3bolQXKbUwTnKGV6toJcWxTuWjLZB+7HGgtIUcs="
		Expected = "0108684685809657215Kx(fy<GS>91EE11<GS>92wYwa3bolQXKbUwTnKGV6toJcWxTuWjLZB+7HGgtIUcs="
	}
	[pscustomobject]@{
		Name = "Serial number without AI-like text"
		Input = "01086846857944892150jhyS91EE1192jUkEVifhq11r0liAifZwm3JElGmXrbwC+VCazzojMAc="
		Expected = "01086846857944892150jhyS<GS>91EE11<GS>92jUkEVifhq11r0liAifZwm3JElGmXrbwC+VCazzojMAc="
	}
	[pscustomobject]@{
		Name = "AI 92 in parentheses"
		Input = "(01)08684685809657(21)5Kx(fy91EE11(92)wYwa3bolQXKbUwTnKGV6toJcWxTuWjLZB+7HGgtIUcs="
		Expected = "0108684685809657215Kx(fy<GS>91EE11<GS>92wYwa3bolQXKbUwTnKGV6toJcWxTuWjLZB+7HGgtIUcs="
	}
	[pscustomobject]@{
		Name = "AI 91 and AI 92 in parentheses"
		Input = "(01)08684147291136(21)5g-d0H25y)S4;(91)EE10(92)TQjIbJkOVA4BKixwvvaRCULWpfppQaEZ2CVj7HiuBIY="
		Expected = "0108684147291136215g-d0H25y)S4;<GS>91EE10<GS>92TQjIbJkOVA4BKixwvvaRCULWpfppQaEZ2CVj7HiuBIY="
	}
)

$testCode = foreach ($testCase in $testCases) {
	$inputLiteral = '"' + $testCase.Input.Replace('"', '""') + '"'
	$expectedLiteral = '"' + $testCase.Expected.Replace('"', '""') + '"'
	@"
ВходнойКод = $inputLiteral;
ВходнойКод = СтрЗаменить(ВходнойКод, "(01)", "01");
ВходнойКод = СтрЗаменить(ВходнойКод, "(21)", "21");
ВходнойКод = СтрЗаменить(ВходнойКод, "(91)", "91");
ВходнойКод = СтрЗаменить(ВходнойКод, "(92)", "92");
ОжидаемыйКод = СтрЗаменить($expectedLiteral, "<GS>", Символ(29));
ФактическийКод = ВосстановитьКодМаркировки(ВходнойКод);
Если ФактическийКод <> ОжидаемыйКод Тогда
	ВызватьИсключение "Test failed: $($testCase.Name). Actual: " + СтрЗаменить(ФактическийКод, Символ(29), "<GS>");
КонецЕсли;
Сообщить("Passed: $($testCase.Name)");
"@
}

$temporaryScript = Join-Path ([System.IO.Path]::GetTempPath()) ("marking-code-tests-" + [guid]::NewGuid().ToString("N") + ".bsl")
try {
	[System.IO.File]::WriteAllText(
		$temporaryScript,
		$source + "`r`n" + ($testCode -join "`r`n"),
		[System.Text.UTF8Encoding]::new($false)
	)

	& $oneScript.Source -check $temporaryScript
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}

	& $oneScript.Source $temporaryScript
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}
finally {
	Remove-Item -LiteralPath $temporaryScript -ErrorAction SilentlyContinue
}
