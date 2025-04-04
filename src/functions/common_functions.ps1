###################################################################################
#
#		共通関数スクリプト
#
###################################################################################
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

# region ガーベッジコレクション

#----------------------------------------------------------------------
# ガーベッジコレクション
#----------------------------------------------------------------------
function Invoke-GarbageCollection() {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	Write-Verbose -Message 'Starting garbage collection ...' ; [System.GC]::Collect()
	Write-Verbose -Message 'Waiting for pending finalizers ...' ; [System.GC]::WaitForPendingFinalizers()
	Write-Verbose -Message 'Performing a final pass of garbage collection ...' ; [System.GC]::Collect()
	Write-Verbose -Message 'Garbage collection completed.'
}

# endregion ガーベッジコレクション

# region タイムスタンプ

#----------------------------------------------------------------------
# タイムスタンプ更新
#----------------------------------------------------------------------
function Get-TimeStamp {
	[CmdletBinding()]
	[OutputType([String])]
	Param ()
	return (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
}

#----------------------------------------------------------------------
# UNIX時間をDateTime型に変換
#----------------------------------------------------------------------
function ConvertFrom-UnixTime {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ([Parameter(Mandatory = $true)][int64]$UnixTime)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$EpochDate = Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0 -AsUTC
	return ($EpochDate.AddSeconds($UnixTime).ToLocalTime())
	Remove-Variable -Name UnixTime, EpochDate -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# DateTime型をUNIX時間に変換
#----------------------------------------------------------------------
function ConvertTo-UnixTime {
	[CmdletBinding()]
	[OutputType([int64])]
	Param ([Parameter(Mandatory = $true)][DateTime]$InputDate)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$unixTime = New-TimeSpan -Start '1970-01-01' -End $InputDate.ToUniversalTime()
	return [int64][math]::Round($unixTime.TotalSeconds)
	Remove-Variable -Name InputDate, unixTime -ErrorAction SilentlyContinue
}

# endregion タイムスタンプ

# region 文字列操作

#----------------------------------------------------------------------
# ファイル名・ディレクトリ名に禁止文字の削除
#----------------------------------------------------------------------
function Get-FileNameWithoutInvalidChars {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$name = '')
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	# 使用する正規表現パターンを定義
	$invalidCharsPattern = '[{0}]' -f [RegEx]::Escape( [IO.Path]::GetInvalidFileNameChars() -Join '')
	$additionalReplaces = '[*\?<>|]'	# Linux/MacではGetInvalidFileNameChars()が不完全なため、ダメ押しで置換
	$nonPrintableChars = '[\x00-\x1F\x7F]'	# ASCII制御文字()
	# 無効な文字を削除
	$name = $name -replace $invalidCharsPattern, '' `
				-replace $additionalReplaces, '-' `
				-replace '--', '-' `
				-replace $nonPrintableChars, ''
	return $name
	Remove-Variable -Name invalidCharsPattern, name, additionalReplaces, nonPrintableChars -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 英数のみ全角→半角(カタカナは全角)
#----------------------------------------------------------------------
function Get-NarrowChars {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$text = '')
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$replaceChars = @{
		'０１２３４５６７８９'                                           = '0123456789'
		'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ' = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
		'＠＃＄％＾＆＊－＋＿／［］｛｝（）＜＞　￥＼”；：．，'                          = '@#$%^&*-+_/[]{}()<> \\";:.,'
	}
	foreach ($entry in $replaceChars.GetEnumerator()) {
		for ($i = 0 ; $i -lt $entry.Name.Length ; $i++) {
			$text = $text.Replace($entry.Name[$i], $entry.Value[$i])
		}
	}
	$replacements = @{
		'ｱ'  = 'ア'
		'ｲ'  = 'イ'
		'ｳ'  = 'ウ'
		'ｴ'  = 'エ'
		'ｵ'  = 'オ'
		'ｶ'  = 'カ'
		'ｷ'  = 'キ'
		'ｸ'  = 'ク'
		'ｹ'  = 'ケ'
		'ｺ'  = 'コ'
		'ｻ'  = 'サ'
		'ｼ'  = 'シ'
		'ｽ'  = 'ス'
		'ｾ'  = 'セ'
		'ｿ'  = 'ソ'
		'ﾀ'  = 'タ'
		'ﾁ'  = 'チ'
		'ﾂ'  = 'ツ'
		'ﾃ'  = 'テ'
		'ﾄ'  = 'ト'
		'ﾅ'  = 'ナ'
		'ﾆ'  = 'ニ'
		'ﾇ'  = 'ヌ'
		'ﾈ'  = 'ネ'
		'ﾉ'  = 'ノ'
		'ﾊ'  = 'ハ'
		'ﾋ'  = 'ヒ'
		'ﾌ'  = 'フ'
		'ﾍ'  = 'ヘ'
		'ﾎ'  = 'ホ'
		'ﾏ'  = 'マ'
		'ﾐ'  = 'ミ'
		'ﾑ'  = 'ム'
		'ﾒ'  = 'メ'
		'ﾓ'  = 'モ'
		'ﾔ'  = 'ヤ'
		'ﾕ'  = 'ユ'
		'ﾖ'  = 'ヨ'
		'ﾗ'  = 'ラ'
		'ﾘ'  = 'リ'
		'ﾙ'  = 'ル'
		'ﾚ'  = 'レ'
		'ﾛ'  = 'ロ'
		'ﾜ'  = 'ワ'
		'ｦ'  = 'ヲ'
		'ﾝ'  = 'ン'
		'ｧ'  = 'ァ'
		'ｨ'  = 'ィ'
		'ｩ'  = 'ゥ'
		'ｪ'  = 'ェ'
		'ｫ'  = 'ォ'
		'ｬ'  = 'ャ'
		'ｭ'  = 'ュ'
		'ｮ'  = 'ョ'
		'ｯ'  = 'ッ'
		'ｰ'  = 'ー'
		'ｳﾞ' = 'ヴ'
		'ｶﾞ' = 'ガ'
		'ｷﾞ' = 'ギ'
		'ｸﾞ' = 'グ'
		'ｹﾞ' = 'ゲ'
		'ｺﾞ' = 'ゴ'
		'ｻﾞ' = 'ザ'
		'ｼﾞ' = 'ジ'
		'ｽﾞ' = 'ズ'
		'ｾﾞ' = 'ゼ'
		'ｿﾞ' = 'ゾ'
		'ﾀﾞ' = 'ダ'
		'ﾁﾞ' = 'ヂ'
		'ﾂﾞ' = 'ヅ'
		'ﾃﾞ' = 'デ'
		'ﾄﾞ' = 'ド'
		'ﾊﾞ' = 'バ'
		'ﾋﾞ' = 'ビ'
		'ﾌﾞ' = 'ブ'
		'ﾍﾞ' = 'ベ'
		'ﾎﾞ' = 'ボ'
		'ﾊﾟ' = 'パ'
		'ﾋﾟ' = 'ピ'
		'ﾌﾟ' = 'プ'
		'ﾍﾟ' = 'ペ'
		'ﾎﾟ' = 'ポ'
	}
	foreach ($replacement in $replacements.GetEnumerator()) {
		$text = $text.Replace($replacement.Name, $replacement.Value)
	}
	return $text
	Remove-Variable -Name text, replaceChars, entry, i, replacements, replacement -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# いくつかの特殊文字を置換
#----------------------------------------------------------------------
function Remove-SpecialCharacter {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$text)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$text = $text.Replace('&amp;', '&')
	$replacements = @{
		'*' = '＊' # 全角
		'|' = '｜' # 全角
		':' = '：' # 全角
		';' = '；' # 全角
		"‘" = "'" # U+2018をU+0027に変換
		"’" = "'" # U+2019をU+0027に変換
		'"' = '' # 削除
		'“' = '' # 全角でもダブルクォートとして認識されるようなので削除
		'”' = '' # 全角でもダブルクォートとして認識されるようなので削除
		'?' = '？' # 全角
		'!' = '！' # 全角
		'/' = '／' # 全角
		'\' = '＼' # 全角
		'<' = '＜' # 全角
		'>' = '＞' # 全角
	}
	foreach ($replacement in $replacements.GetEnumerator()) { $text = $text.Replace($replacement.Name, $replacement.Value) }
	return $text
	Remove-Variable -Name text, replacements, replacement -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# タブとスペースを詰めて半角スペース1文字に
#----------------------------------------------------------------------
function Remove-TabSpace {
	[CmdletBinding()]
	[OutputType([String])]
	Param ([String]$text)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	return $text.Replace("`t", ' ').Replace('  ', ' ')
	Remove-Variable -Name text -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 設定ファイルの行末コメントを削除
#----------------------------------------------------------------------
function Remove-Comment {
	[OutputType([String])]
	Param ([String]$text)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	return $text.Split("`t")[0].Split(' ')[0].Split('#')[0]
	Remove-Variable -Name text -ErrorAction SilentlyContinue
}

# endregion 文字列操作

# region ファイル操作

#----------------------------------------------------------------------
# 指定したPath配下の指定した条件でファイルを削除
#----------------------------------------------------------------------
function Remove-Files {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[parameter(Mandatory = $true)][System.IO.FileInfo]$basePath,
		[Parameter(Mandatory = $true)][String[]]$conditions,
		[Parameter(Mandatory = $true)][int32]$delPeriod
	)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $basePath)
	$limitDateTime = (Get-Date).AddDays(-1 * $delPeriod)
	if ($script:enableMultithread) {
		Write-Debug ('Multithread Processing Enabled')
		# 並列化が有効の場合は並列化
		try {
			$conditions | ForEach-Object -Parallel {
				Write-Output ('　{0}' -f (Join-Path $using:basePath $_))
				(Get-ChildItem -LiteralPath $using:basePath -Recurse -File -Filter $_ -ErrorAction SilentlyContinue).Where({ $_.LastWriteTime -lt $using:limitDateTime }) | Remove-Item -Force -ErrorAction SilentlyContinue | Out-Null
			} -ThrottleLimit $script:multithreadNum
		} catch { Write-Warning ($script:msg.FileCannotBeDeleted) }
	} else {
		# 並列化が無効の場合は従来型処理
		try {
			foreach ($condition in $conditions) {
				Write-Output ('　{0}' -f (Join-Path $basePath $condition))
				(Get-ChildItem -LiteralPath $basePath -Recurse -File -Filter $condition -ErrorAction SilentlyContinue).Where({ $_.LastWriteTime -lt $limitDateTime }) | Remove-Item -Force -ErrorAction SilentlyContinue | Out-Null
			}
		} catch { Write-Warning ($script:msg.FileCannotBeDeleted) }
	}
	Remove-Variable -Name basePath, conditions, delPeriod, limitDateTime, condition -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# Zipファイルを解凍
#----------------------------------------------------------------------
function Expand-Zip {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true)][String]$path,
		[Parameter(Mandatory = $true)][String]$destination
	)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)
	if (Test-Path -Path $path) {
		Write-Verbose ('Extracting {0} into {1}' -f $path, $destination)
		[System.IO.Compression.ZipFile]::ExtractToDirectory($path, $destination, $true)
		Write-Verbose ('Extracted {0}' -f $path)
	} else { Throw ($script:msg.FileNotFound -f $path) }
	Remove-Variable -Name path, destination -ErrorAction SilentlyContinue
}

# endregion ファイル操作

# region ファイルロック

#----------------------------------------------------------------------
# ファイルのロック
#----------------------------------------------------------------------
function Lock-File {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param ([parameter(Mandatory = $true)][String]$path)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)
	try {
		# ファイルを開こうとしファイルロックを検出
		$script:fileInfo[$path] = [System.IO.FileInfo]::new($path)
		$script:fileStream[$path] = $script:fileInfo[$path].Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
		$result = $true
	} catch { $result = $false }
	# 結果の返却
	return [PSCustomObject]@{
		path   = $path
		result = $result
	}
	Remove-Variable -Name path, fileLocked, result -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# ファイルのアンロック
#----------------------------------------------------------------------
function Unlock-File {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param ([parameter(Mandatory = $true)][String]$path)
	Write-Debug ('{0} - {1}' -f $MyInvocation.MyCommand.Name, $path)
	if (Test-Path $path) {
		if ($script:fileStream[$path]) {
			# ロックされていなければストリームを閉じる
			$script:fileStream[$path].Close()
			$script:fileStream[$path].Dispose()
			$script:fileStream[$path] = $null
			$script:fileStream.Remove($path)
		}
		$result = $true
	} else { $result = $false }
	# 結果の返却
	return [PSCustomObject]@{
		path   = $path
		result = $result
	}
	Remove-Variable -Name path, fileLocked, result -ErrorAction SilentlyContinue
}

# endregion ファイルロック

# region ディスク監視
#----------------------------------------------------------------------
# ディレクトリの空き容量確認(MB)
#----------------------------------------------------------------------
function Get-RemainingCapacity {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)][string]$targetDir
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($IsWindows) {
		try {
			switch -Regex ($targetDir) {
				'^[a-zA-Z]:' {
					# ローカルディスクまたはマウントされたネットワークドライブ (例: "C:\", "Z:\")
					$targetDrive = $targetDir.Substring(0, 2)  # "C:" or "Z:"
					$freeSpace = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$targetDrive'").FreeSpace
					break
				}
				'^\\\\' {
					# UNC パス (例: "\\server\share")
					$targetRoot = ($targetDir -replace '(^\\\\[^\\]+\\[^\\]+).*', '$1')  # \\server\share
					$freeSpace = (& cmd /c dir $targetRoot) | Select-Object -Last 1 | ForEach-Object { $_ -replace ',' -split '\s+' } | Select-Object -Index 3
					break
				}
				default { Write-Information ($script:msg.CapacityUnknown -f $targetDir) ; $freeSpace = 9999999999 }
			}
		} catch { Write-Information ($script:msg.CapacityUnknown -f $targetDir) ; $freeSpace = 9999999999 }
	} else {
		$dfCmd = "df -P `"$targetDir`""
		$freeSpace = [int64](((& sh -c $dfCmd) | Select-Object -Skip 1) -split '\s+')[3] * 1024
	}
	return [int64]($freeSpace / 1MB)
	Remove-Variable -Name targetDir, targetDrive, freeSpace, targetRoot -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# リネームに失敗したファイルを削除
#----------------------------------------------------------------------
function Remove-UnRenamedTempFiles {
	[CmdletBinding()]
	Param ()
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($IsWindows) {
		$forCmd = "for %E in (mp4 ts) do for /r `"$script:downloadBaseDir`" %F in (ep*.%E) do @echo %F"
		(& cmd /c $forCmd) |
				Where-Object { ($_ -cmatch 'ep[a-z0-9]{8}.mp4$') -or ($_ -cmatch 'ep[a-z0-9]{8}.ts$') } |
				Remove-Item -Force -ErrorAction SilentlyContinue
	} else {
		$findCmd = "find `"$script:downloadBaseDir`" -type f -name 'ep*.mp4' -or -type f -name 'ep*.ts'"
		(& sh -c $findCmd) |
				Where-Object { ($_ -cmatch 'ep[a-z0-9]{8}.mp4$') -or ($_ -cmatch 'ep[a-z0-9]{8}.ts$') } |
				Remove-Item -Force -ErrorAction SilentlyContinue
	}
}
# endregion ディスク監視

# region ファイルロック

#----------------------------------------------------------------------
# 色付きWrite-Output
#----------------------------------------------------------------------
function Out-Msg-Color {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $false)][Object]$text = '',
		[Parameter(Mandatory = $false)][ConsoleColor]$fg,
		[Parameter(Mandatory = $false)][ConsoleColor]$bg,
		[Parameter(Mandatory = $false)][Boolean]$noNL
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$prevFg = $host.UI.RawUI.ForegroundColor
	$prevBg = $host.UI.RawUI.BackgroundColor
	if ($fg) { $host.UI.RawUI.ForegroundColor = $fg }
	if ($bg) { $host.UI.RawUI.BackgroundColor = $bg }
	$writeHostParams = @{
		Object    = $text
		NoNewline = $noNL
	}
	Write-Host @writeHostParams
	$host.UI.RawUI.ForegroundColor = $prevFg
	$host.UI.RawUI.BackgroundColor = $prevBg
	Remove-Variable -Name text, fg, bg, noNL, prevFg, prevBg, writeHostParams -ErrorAction SilentlyContinue
}

# endregion コンソール出力

# region トースト通知

# モジュールのインポート
if ($IsWindows -and !$script:disableToastNotification -and (!('Microsoft.Toolkit.Uwp.Notifications.ToastContentBuilder' -as [Type]))) {
	Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Windows.SDK.NET.dll') | Out-Null
	Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/WinRT.Runtime.dll') | Out-Null
	Add-Type -LiteralPath (Join-Path $script:libDir 'win/core/Microsoft.Toolkit.Uwp.Notifications.dll') | Out-Null
}

#----------------------------------------------------------------------
# トースト表示
#----------------------------------------------------------------------
function Show-GeneralToast {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$text1,
		[Parameter(Mandatory = $false)][String]$text2 = '',
		[Parameter(Mandatory = $false)][ValidateSet('Short', 'Long')][String]$duration = 'Short',
		[Parameter(Mandatory = $false)][Boolean]$silent = $false
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!$script:disableToastNotification) {
		switch ($true) {
			$IsWindows {
				$toastSoundElement = if ($silent) { '<audio silent="true" />' }
				else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
				$toastProgressContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$duration">
    <visual>
        <binding template="ToastGeneric">
            <text>$script:appName</text>
            <text>$text1</text>
            <text>$text2</text>
            <image placement="appLogoOverride" src="$script:toastAppLogo"/>
        </binding>
    </visual>
    $toastSoundElement
</toast>
"@
				$toastXML = [Windows.Data.Xml.Dom.XmlDocument]::new()
				$toastXML.LoadXml($toastProgressContent)
				$toastNotification = [Windows.UI.Notifications.ToastNotification]::new($toastXML)
				[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Show($toastNotification) | Out-Null
				break
			}
			$IsLinux {
				if (Get-Command notify-send -ErrorAction SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 2> /dev/null }
				break
			}
			$IsMacOS {
				if (Get-Command osascript -ErrorAction SilentlyContinue) {
					$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
					$toastParams | & osascript 2> /dev/null
				}
				break
			}
			default {}
		}
	}
	Remove-Variable -Name text1, text2, duration, silent, toastSoundElement, toastProgressContent, toastXML, toastNotification, toastParams -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 進捗バー付きトースト表示
#----------------------------------------------------------------------
function Show-ProgressToast {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$text1,
		[Parameter(Mandatory = $false)][String]$text2 = '',
		[Parameter(Mandatory = $false)][String]$workDetail = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $true )][String]$group,
		[Parameter(Mandatory = $false)][ValidateSet('Short', 'Long')][String]$duration = 'Short',
		[Parameter(Mandatory = $false)][Boolean]$silent = $false
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!$script:disableToastNotification) {
		switch ($true) {
			$IsWindows {
				$toastSoundElement = if ($silent) { '<audio silent="true" />' }
				else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
				$toastContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$duration">
    <visual>
        <binding template="ToastGeneric">
            <text>$script:appName</text>
            <text>$text1</text>
            <text>$text2</text>
            <image placement="appLogoOverride" src="$script:toastAppLogo"/>
            <progress value="{progressValue}" title="{progressTitle}" valueStringOverride="{progressValueString}" status="{progressStatus}" />
            <text placement="attribution"></text>
        </binding>
    </visual>
    $toastSoundElement
</toast>
"@
				$toastXML = [Windows.Data.Xml.Dom.XmlDocument]::new()
				$toastXML.LoadXml($toastContent)
				$toast = [Windows.UI.Notifications.ToastNotification]::new($toastXML)
				$toast.Tag = $tag
				$toast.Group = $group
				$toastData = [System.Collections.Generic.Dictionary[String, String]]::new()
				$toastData.Add('progressTitle', $workDetail) | Out-Null
				$toastData.Add('progressValue', '') | Out-Null
				$toastData.Add('progressValueString', '') | Out-Null
				$toastData.Add('progressStatus', '') | Out-Null
				$toast.Data = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toast.Data.SequenceNumber = 1
				[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Show($toast) | Out-Null
				break
			}
			$IsLinux {
				if (Get-Command notify-send -ErrorAction SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 2> /dev/null }
				break
			}
			$IsMacOS {
				if (Get-Command osascript -ErrorAction SilentlyContinue) {
					$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
					$toastParams | & osascript
				}
				break
			}
			default {}
		}
	}
	Remove-Variable -Name text1, text2, workDetail, tag, group, duration, silent, toastSoundElement, toastContent, toastXML, toast, toastData, toastParams -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 進捗バー付きトースト更新
#----------------------------------------------------------------------
function Update-ProgressToast {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $false)][String]$title = '',
		[Parameter(Mandatory = $true )][String]$rate,
		[Parameter(Mandatory = $false)][String]$leftText = '',
		[Parameter(Mandatory = $false)][String]$rightText = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $true )][String]$group
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!$script:disableToastNotification) {
		switch ($true) {
			$IsWindows {
				$toastData = [System.Collections.Generic.Dictionary[String, String]]::new()
				$toastData.Add('progressTitle', $title) | Out-Null
				$toastData.Add('progressValue', $rate) | Out-Null
				$toastData.Add('progressValueString', $rightText) | Out-Null
				$toastData.Add('progressStatus', $leftText) | Out-Null
				$toastProgressData = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toastProgressData.SequenceNumber = 2
				[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Update($toastProgressData, $tag , $group) | Out-Null
				break
			}
			$IsLinux { break }
			$IsMacOS { break }
			default {}
		}
	}
	Remove-Variable -Name title, rate, leftText, rightText, tag, group, toastData, toastProgressData -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 進捗表示(2行進捗バー)
#----------------------------------------------------------------------
function Show-ProgressToast2Row {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $true )][String]$text1,
		[Parameter(Mandatory = $false)][String]$text2 = '',
		[Parameter(Mandatory = $false)][String]$detail1 = '',
		[Parameter(Mandatory = $false)][String]$detail2 = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $false)][ValidateSet('Short', 'Long')][String]$duration = 'Short',
		[Parameter(Mandatory = $false)][Boolean]$silent = $false,
		[Parameter(Mandatory = $true )][String]$group
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!$script:disableToastNotification) {
		$text2 = $text2 ?? ''
		$detail1 = $detail1 ?? ''
		$detail2 = $detail2 ?? ''
		switch ($true) {
			$IsWindows {
				$toastSoundElement = if ($silent) { '<audio silent="true" />' } else { '<audio src="ms-winsoundevent:Notification.Default" loop="false"/>' }
				$duration = if (!$duration) { 'short' } else { $duration }
				$toastAttribution = ''
				$toastContent = @"
<?xml version="1.0" encoding="utf-8"?>
<toast duration="$duration">
	<visual>
		<binding template="ToastGeneric">
			<text>$script:appName</text>
			<text>$text1</text>
			<text>$text2</text>
			<image placement="appLogoOverride" src="$script:toastAppLogo"/>
			<progress value="{progressValue1}" title="{progressTitle1}" valueStringOverride="{progressValueString1}" status="{progressStatus1}" />
			<progress value="{progressValue2}" title="{progressTitle2}" valueStringOverride="{progressValueString2}" status="{progressStatus2}" />
			<text placement="attribution">$toastAttribution</text>
		</binding>
	</visual>
	$toastSoundElement
</toast>
"@
				$toastXML = [Windows.Data.Xml.Dom.XmlDocument]::new()
				$toastXML.LoadXml($toastContent)
				$toast = [Windows.UI.Notifications.ToastNotification]::new($toastXML)
				$toast.Tag = $tag
				$toast.Group = $group
				$toastData = [System.Collections.Generic.Dictionary[String, String]]::new()
				$toastData.Add('progressTitle1', $detail1) | Out-Null
				$toastData.Add('progressValue1', '') | Out-Null
				$toastData.Add('progressValueString1', '') | Out-Null
				$toastData.Add('progressStatus1', '') | Out-Null
				$toastData.Add('progressTitle2', $detail2) | Out-Null
				$toastData.Add('progressValue2', '') | Out-Null
				$toastData.Add('progressValueString2', '') | Out-Null
				$toastData.Add('progressStatus2', '') | Out-Null
				$toast.Data = [Windows.UI.Notifications.NotificationData]::new($toastData)
				$toast.Data.SequenceNumber = 1
				[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Show($toast) | Out-Null
				break
			}
			$IsLinux {
				if (Get-Command notify-send -ErrorAction SilentlyContinue) { & notify-send -a $script:appName -t 5000 -i $script:toastAppLogo $text1 $text2 2> /dev/null }
				break
			}
			$IsMacOS {
				if (Get-Command osascript -ErrorAction SilentlyContinue) {
					$toastParams = ('display notification "{0}" with title "{1}" subtitle "{2}" sound name "Blow"' -f $text2, $script:appName, $text1)
					$toastParams | & osascript
				}
				break
			}
			default {}
		}
	}
	Remove-Variable -Name text1, text2, detail1, detail2, tag, duration, silent, group, toastSoundElement, toastAttribution, toastContent, toastXML, toast, toastData, toastParams -ErrorAction SilentlyContinue
}

#----------------------------------------------------------------------
# 進捗更新(2行進捗バー)
#----------------------------------------------------------------------
function Update-ProgressToast2Row {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $false)][String]$title1 = '',
		[Parameter(Mandatory = $true )][String]$rate1,
		[Parameter(Mandatory = $false)][String]$leftText1 = '',
		[Parameter(Mandatory = $false)][String]$rightText1 = '',
		[Parameter(Mandatory = $false)][String]$title2 = '',
		[Parameter(Mandatory = $true )][String]$rate2,
		[Parameter(Mandatory = $false)][String]$leftText2 = '',
		[Parameter(Mandatory = $false)][String]$rightText2 = '',
		[Parameter(Mandatory = $true )][String]$tag,
		[Parameter(Mandatory = $true )][String]$group
	)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if (!($script:disableToastNotification)) {
		$rightText1 = switch ($rightText1 ) {
			'' { '' ; break }
			'0' { $script:msg.Completed ; break }
			default { ($script:msg.MinRemaining -f ([Int][Math]::Ceiling($rightText1 / 60))) }
		}
		$rightText2 = switch ($rightText2 ) {
			'' { '' ; break }
			'0' { $script:msg.Completed ; break }
			default { ($script:msg.MinRemaining -f ([Int][Math]::Ceiling($rightText2 / 60))) }
		}
		if (!$script:disableToastNotification) {
			switch ($true) {
				$IsWindows {
					$toastData = [System.Collections.Generic.Dictionary[String, String]]::new()
					$toastData.Add('progressTitle1', $title1) | Out-Null
					$toastData.Add('progressValue1', $rate1) | Out-Null
					$toastData.Add('progressValueString1', $rightText1) | Out-Null
					$toastData.Add('progressStatus1', $leftText1) | Out-Null
					$toastData.Add('progressTitle2', $title2) | Out-Null
					$toastData.Add('progressValue2', $rate2) | Out-Null
					$toastData.Add('progressValueString2', $rightText2) | Out-Null
					$toastData.Add('progressStatus2', $leftText2)
					$toastProgressData = [Windows.UI.Notifications.NotificationData]::new($toastData)
					$toastProgressData.SequenceNumber = 2
					[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($script:appID).Update($toastProgressData, $tag , $group) | Out-Null
					break
				}
				$IsLinux { break }
				$IsMacOS { break }
				default {}
			}
		}
	}
	Remove-Variable -Name title1, rate1, leftText1, rightText1, title2, rate2, leftText2, rightText2, tag, group, toastData, toastProgressData -ErrorAction SilentlyContinue
}
# endregion トースト通知

#----------------------------------------------------------------------
# Base64画像の展開
#----------------------------------------------------------------------
function ConvertFrom-Base64 {
	Param ($base64)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$img = [System.Windows.Media.Imaging.BitmapImage]::new()
	$img.BeginInit()
	$img.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($base64)
	$img.EndInit()
	$img.Freeze()
	return $img
	Remove-Variable -Name base64, img -ErrorAction SilentlyContinue
}
