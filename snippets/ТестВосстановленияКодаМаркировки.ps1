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
	[pscustomobject]@{
		Name = "Marking code 08685003514888"
		Input = "(01)08685003514888(21)5Vg015Vyc(&OI(91)EE12(92)GDEvB/ABg7A8dB5mkH44VdWRI11xTPNuFsekfBMJm2Y="
		Expected = "0108685003514888215Vg015Vyc(&OI<GS>91EE12<GS>92GDEvB/ABg7A8dB5mkH44VdWRI11xTPNuFsekfBMJm2Y="
	}
	[pscustomobject]@{
		Name = "Marking code 08685005831259"
		Input = "(01)08685005831259(21)5RY-cNPWgbuZo(91)EE12(92)n3ConLqYCPFBThKJ07fWJLR3RaD2qvC+JD/hnIGEIUM="
		Expected = "0108685005831259215RY-cNPWgbuZo<GS>91EE12<GS>92n3ConLqYCPFBThKJ07fWJLR3RaD2qvC+JD/hnIGEIUM="
	}
	[pscustomobject]@{
		Name = "Marking code 08685000787858"
		Input = "(01)08685000787858(21)5XrGVqX8YrQ;V(91)EE12(92)pAbF21mm4TaKXVCLBUu4yluei4McaRsSZYrib1NE4Ag="
		Expected = "0108685000787858215XrGVqX8YrQ;V<GS>91EE12<GS>92pAbF21mm4TaKXVCLBUu4yluei4McaRsSZYrib1NE4Ag="
	}
	[pscustomobject]@{
		Name = "Marking code 08685006240944"
		Input = "(01)08685006240944(21)5V7_TKVTxX+eu(91)EE12(92)wqhFX0F8r+uZrR41fd8frbP0phh6mvutIZ515MU/u18="
		Expected = "0108685006240944215V7_TKVTxX+eu<GS>91EE12<GS>92wqhFX0F8r+uZrR41fd8frbP0phh6mvutIZ515MU/u18="
	}
	[pscustomobject]@{
		Name = "Marking code 08685001320283"
		Input = "(01)08685001320283(21)5wRpE;pH&!':S(91)EE12(92)5hKm896HCYm+/MhsmG4SZsOhBUjaTg8QK5VX7xjvEGw="
		Expected = "0108685001320283215wRpE;pH&!':S<GS>91EE12<GS>925hKm896HCYm+/MhsmG4SZsOhBUjaTg8QK5VX7xjvEGw="
	}
	[pscustomobject]@{
		Name = "Marking code 08685001320306"
		Input = "(01)08685001320306(21)5bHHN8T(DJS)y(91)EE12(92)ZobfQoEjKnQzNKXOyhlEbe5Fu8l0lwCGYQb+8VGNzfk="
		Expected = "0108685001320306215bHHN8T(DJS)y<GS>91EE12<GS>92ZobfQoEjKnQzNKXOyhlEbe5Fu8l0lwCGYQb+8VGNzfk="
	}
	[pscustomobject]@{
		Name = "Marking code 08685000771796"
		Input = "(01)08685000771796(21)5.92Go7OT6xUW(91)EE12(92)IR375h9qqEmqNfWgmNQ6qqKeRkDbBMK60Ab5eq640v4="
		Expected = "0108685000771796215.92Go7OT6xUW<GS>91EE12<GS>92IR375h9qqEmqNfWgmNQ6qqKeRkDbBMK60Ab5eq640v4="
	}
	[pscustomobject]@{
		Name = "Marking code 08685001300766"
		Input = "(01)08685001300766(21)5qnMB%OZ7rp80(91)EE12(92)itxYiu96/IzOKIR4OH/eQAhlAQlWJMmm8sJYsQw9XF4="
		Expected = "0108685001300766215qnMB%OZ7rp80<GS>91EE12<GS>92itxYiu96/IzOKIR4OH/eQAhlAQlWJMmm8sJYsQw9XF4="
	}
	[pscustomobject]@{
		Name = "Marking code 08685001019705"
		Input = "(01)08685001019705(21)5seGCd'+4ttJH(91)EE12(92)bNveYkQREaMiBoYtXe3Ax7cQ0dVH5NkS1EII8l/0uAM="
		Expected = "0108685001019705215seGCd'+4ttJH<GS>91EE12<GS>92bNveYkQREaMiBoYtXe3Ax7cQ0dVH5NkS1EII8l/0uAM="
	}
	[pscustomobject]@{
		Name = "Marking code 08685000747579"
		Input = "(01)08685000747579(21)5&m.MWYWkLW>8(91)EE12(92)w2Eqyx+Gv9lyq/bZH4l6RCfoFvXoZwkwF/1cJ744Jdg="
		Expected = "0108685000747579215&m.MWYWkLW>8<GS>91EE12<GS>92w2Eqyx+Gv9lyq/bZH4l6RCfoFvXoZwkwF/1cJ744Jdg="
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
