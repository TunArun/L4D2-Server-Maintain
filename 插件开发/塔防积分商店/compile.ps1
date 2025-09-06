# 定义路径变量
$spcomp = "E:\yincang\Games\L4D2\插件开发\插件平台\addons\sourcemod\scripting\spcomp.exe"
$include = "E:\yincang\Games\L4D2\插件开发\插件平台\addons\sourcemod\scripting\include"
$compiledDir = ".\compiled"
$remotePath = "root@tencent:~steam/l4d2server/left4dead2/addons/sourcemod/plugins"  # 替换为实际的远程路径

# 检查 spcomp.exe 是否存在
if (-not (Test-Path $spcomp)) {
    Write-Host "错误：未找到 spcomp.exe，请检查路径是否正确。"
    exit 1
}

# 检查是否存在 compiled 文件夹，如果不存在则创建
if (-not (Test-Path $compiledDir)) {
    New-Item -ItemType Directory -Path $compiledDir | Out-Null
}

# 显示菜单
function Show-Menu {
    Clear-Host
    Write-Host "请选择操作："
    Write-Host "1. 编译 .sp 文件"
    Write-Host "2. 上传 .smx 文件到远程路径"
    Write-Host "3. 退出"
}

# 编译选定的 .sp 文件
function Build-SPFiles {
    Write-Host "当前目录下的 .sp 文件："
    $spFiles = Get-ChildItem -Path ".\" -Filter "*.sp"
    if ($spFiles.Count -eq 0) {
        Write-Host "错误：未找到 .sp 文件。"
        return
    }
    for ($i = 0; $i -lt $spFiles.Count; $i++) {
        Write-Host "$($i + 1). $($spFiles[$i].Name)"
    }
    $choice = Read-Host "请选择要编译的文件 (输入编号)"
    if ($choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $spFiles.Count) {
        $selectedFile = $spFiles[$choice - 1]
        $outputPath = Join-Path $compiledDir "$($selectedFile.BaseName).smx"
        & $spcomp -i="$include" -o="$outputPath" "$($selectedFile.FullName)"
        Write-Host "已编译: $($selectedFile.Name) -> $outputPath"
    } else {
        Write-Host "无效选择。"
    }
}

# 上传选定的 .smx 文件
function Upload-SMXFiles {
    Write-Host "compiled 目录下的 .smx 文件："
    $smxFiles = Get-ChildItem -Path $compiledDir -Filter "*.smx"
    if ($smxFiles.Count -eq 0) {
        Write-Host "错误：未找到 .smx 文件。"
        return
    }
    for ($i = 0; $i -lt $smxFiles.Count; $i++) {
        Write-Host "$($i + 1). $($smxFiles[$i].Name)"
    }
    $choice = Read-Host "请选择要上传的文件 (输入编号)"
    if ($choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $smxFiles.Count) {
        $selectedFile = $smxFiles[$choice - 1]
        scp "$($selectedFile.FullName)" "$remotePath"
        Write-Host "已上传: $($selectedFile.Name) -> $remotePath"
    } else {
        Write-Host "无效选择。"
    }
}

# 主循环
do {
    Show-Menu
    $choice = Read-Host "请输入选项 (1-3)"
    switch ($choice) {
        "1" { Build-SPFiles }
        "2" { Upload-SMXFiles }
        "3" { Write-Host "退出脚本。"; break }
        default { Write-Host "无效选项，请重新选择。" }
    }
    if ($choice -ne "3") {
        Read-Host "按 Enter 键继续..."
    }
} while ($choice -ne "3")
