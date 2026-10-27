
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile('C:\Users\toopt\Desktop\x2.png')
$w_f = $img.Width / 6
$h_f = $img.Height / 3
$folder = 'C:\Users\toopt\Desktop\frames_output'
if (!(Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder | Out-Null
}
for ($r=0; $r -lt 3; $r++) {
    for ($c=0; $c -lt 6; $c++) {
        $fw = [int]$w_f
        $fh = [int]$h_f
        $bmp = New-Object System.Drawing.Bitmap($fw, $fh)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $destRect = New-Object System.Drawing.Rectangle(0, 0, $fw, $fh)
        $srcRect = New-Object System.Drawing.Rectangle([int]($c*$w_f), [int]($r*$h_f), $fw, $fh)
        $g.DrawImage($img, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
        $idx = $r * 6 + $c + 1
        $name = "frame_$idx.png"
        $path = Join-Path $folder $name
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose()
        $bmp.Dispose()
    }
}
$img.Dispose()
Write-Host "Done! Frames saved in $folder"
