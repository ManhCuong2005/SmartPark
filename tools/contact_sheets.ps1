Add-Type -AssemblyName System.Drawing
$groups = @(@('13_3','13_25','13_61','13_96'),@('13_139','13_236','13_333','13_429'),@('16_7','16_73','16_134','16_176','16_228'),@('16_390','16_451','16_508','16_590'),@('27_7','27_42','27_110','27_144','27_191'))
for($groupIndex=0;$groupIndex -lt $groups.Count;$groupIndex++){
  $ids=$groups[$groupIndex]
  $sheet=New-Object System.Drawing.Bitmap ($ids.Count*195),864
  $graphics=[System.Drawing.Graphics]::FromImage($sheet)
  $graphics.Clear([System.Drawing.Color]::White)
  for($i=0;$i -lt $ids.Count;$i++){
    $id=$ids[$i]
    $ref=[System.Drawing.Image]::FromFile((Join-Path (Get-Location) "docs\figma\reference_$id.png"))
    $actual=[System.Drawing.Image]::FromFile((Join-Path (Get-Location) "test\goldens\$id.png"))
    $graphics.DrawImage($ref,$i*195,20,195,422)
    $graphics.DrawImage($actual,$i*195,442,195,422)
    $graphics.DrawString($id,(New-Object System.Drawing.Font 'Arial',10),[System.Drawing.Brushes]::Black,$i*195,0)
    $ref.Dispose();$actual.Dispose()
  }
  $sheet.Save((Join-Path (Get-Location) "docs\comparison_$($groupIndex+1).png"),[System.Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose();$sheet.Dispose()
}
