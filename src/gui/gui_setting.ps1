###################################################################################
#
#		GUI設定スクリプト
#
###################################################################################
using namespace System.Windows.Threading
Set-StrictMode -Version Latest
if (!$IsWindows) { Throw ('❌️ Windows以外では動作しません') ; Start-Sleep 10 }
Add-Type -AssemblyName System.Windows.Forms | Out-Null
Add-Type -AssemblyName PresentationFramework | Out-Null

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# region 環境設定

try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	$script:scriptRoot = Convert-Path (Join-Path $script:scriptRoot '../')
	Set-Location $script:scriptRoot
} catch { Throw ('❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.') }
if ($script:scriptRoot.Contains(' ')) { Throw ('❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space') }

#----------------------------------------------------------------------
# メッセージファイル読み込み
$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
$script:langDir = Convert-Path (Join-Path $scriptRoot '../resources/lang')
$script:uiCulture = [System.Globalization.CultureInfo]::CurrentUICulture.Name
Write-Debug "Current Language: $script:uiCulture"
$script:langFile = Get-Content -Path (Join-Path $script:langDir 'messages.json') | ConvertFrom-Json
$script:msg = if (($script:langFile | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Contains($script:uiCulture)) { $script:langFile.$script:uiCulture }
else { $defaultLang = 'en-US'; $script:langFile.$defaultLang }
Write-Debug "Message Table Loaded: $script:uiCulture"

#----------------------------------------------------------------------
# 設定ファイル読み込み
$script:confDir = Convert-Path (Join-Path $script:scriptRoot '../conf')
if ( Test-Path (Join-Path $script:confDir 'system_setting.ps1') ) {
	try { . (Convert-Path (Join-Path $script:confDir 'system_setting.ps1')) }
	catch { Throw ($script:msg.LoadSystemSettingFailed) }
} else { Throw ($script:msg.SystemSettingNotFound) }
if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) {
	try { . (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')) }
	catch { Throw ($script:msg.LoadUserSettingFailed) }
} else { New-Item (Join-Path $script:confDir 'user_setting.ps1') -Force | Out-Null }
if ($script:preferredLanguage) {
	$script:msg = if (($script:langFile | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name).Contains($script:preferredLanguage)) { $script:langFile.$script:preferredLanguage }
	else { $defaultLang = 'en-US'; $script:langFile.$defaultLang }
}

#----------------------------------------------------------------------
# 外部関数ファイルの読み込み
try {
	. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/common_functions.ps1'))
} catch { Throw ($script:msg.LoadCommonFuncFailed) }

$days = @('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')
$hours = 0..23
$userSettingFile = Join-Path $script:confDir 'user_setting.ps1'
$settingAttributes = @(
	'$script:downloadBaseDir',
	'$script:downloadWorkDir',
	'$script:saveBaseDir',
	'$script:parallelDownloadFileNum',
	'$script:parallelDownloadNumPerFile',
	'$script:ytdlTimeoutSec',
	'$script:minDownloadWorkDirCapacity',
	'$script:minDownloadBaseDirCapacity',
	'$script:loopCycle',
	'$script:myPlatformUID',
	'$script:myPlatformToken',
	'$script:myMemberSID',
	'$script:enableMultithread',
	'$script:multithreadNum',
	'$script:disableToastNotification',
	'$script:rateLimit',
	'$script:timeoutSec',
	'$script:guiMaxExecLogLines',
	'$script:histRetentionPeriod',
	'$script:sortVideoBySeries',
	'$script:sortVideoByMedia',
	'$script:addSeriesName',
	'$script:addSeasonName',
	'$script:addBroadcastDate',
	'$script:addEpisodeNumber',
	'$script:removeSpecialNote',
	'$script:preferredYoutubedl',
	'$script:disableUpdateYoutubedl',
	'$script:disableUpdateFfmpeg',
	'$script:forceSoftwareDecodeFlag',
	'$script:simplifiedValidation',
	'$script:disableValidation',
	'$script:sitemapParseEpisodeOnly',
	'$script:downloadWhenEpisodeIdChanged',
	'$script:detailedProgress',
	'$script:embedSubtitle',
	'$script:embedMetatag',
	'$script:windowShowStyle',
	'$script:ffmpegDecodeOption',
	'$script:ytdlOption',
	'$script:ytdlNonTVerFileName',
	'$script:forceSingleDownload',
	'$script:extractDescTextToList',
	'$script:listGenHistoryCheck',
	'$script:updateChannel',
	'$script:videoContainerFormat',
	'$script:cleanupDownloadBaseDir',
	'$script:cleanupSaveBaseDir',
	'$script:emptyDownloadBaseDir',
	'$script:ytdlHttpHeader',
	'$script:ytdlBaseArgs',
	'$script:nonTVerYtdlBaseArgs',
	'$script:proxyUrl',
	'$script:ytdlRandomIp',
	'$script:scheduleStop',
	'$script:preferredLanguage'
)

# endregion 環境設定

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# region 関数定義

# GUIイベントの処理
function Sync-WpfEvents {
	[OutputType([Void])]
	Param ()
	[DispatcherFrame] $frame = [DispatcherFrame]::new($true)
	[Dispatcher]::CurrentDispatcher.BeginInvoke(
		'Background',
		[DispatcherOperationCallback] {
			Param ([Object] $f)
			($f -as [DispatcherFrame]).Continue = $false
			return $null
		},
		$frame) | Out-Null
	[Dispatcher]::PushFrame($frame)
	Remove-Variable -Name frame, f -ErrorAction SilentlyContinue
}

# ディレクトリ選択ダイアログ
function Select-Folder() {
	[OutputType([Void])]
	Param (
		[parameter(Mandatory = $true)]$description,
		[parameter(Mandatory = $true)]$textBox
	)
	$fd = [System.Windows.Forms.FolderBrowserDialog]::new()
	$fd.Description = $description
	$fd.RootFolder = [System.Environment+SpecialFolder]::MyComputer
	$fd.SelectedPath = $textBox.Text
	if ($fd.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) { $textBox.Text = $fd.SelectedPath }
	Remove-Variable -Name description, textBox, fd -ErrorAction SilentlyContinue
}

# user_setting.ps1から各設定項目を読み込む
function Read-UserSetting {
	[OutputType([Void])]
	Param ()
	$undefAttributes = @('$script:downloadBaseDir', '$script:downloadWorkDir', '$script:saveBaseDir', '$script:myPlatformUID', '$script:myPlatformToken', '$script:myMemberSID', '$script:proxyUrl')
	$userSettings = Get-Content -LiteralPath $userSettingFile -Encoding UTF8
	# 動作停止設定以外の抽出
	foreach ($settingAttribute in $settingAttributes) {
		# 変数名から「$script:」を取った名前がBox名
		$settingBox = $settingWindow.FindName($settingAttribute.Replace('$script:', ''))
		if ($null -eq $settingBox) { Write-Debug "$settingAttribute is null" ; continue }
		# ユーザー設定の値を取得しGUIに反映
		$userSettingValue = ($userSettings -match ('^{0}' -f [RegEx]::Escape($settingAttribute)))
		if ($userSettingValue) {
			Write-Debug [String]$userSettingValue
			$settingBox.Text = $userSettingValue.split('=', 2)[1].Trim().Trim("'")
			if ($settingBox.Name -eq 'preferredLanguage') {
				switch ($settingBox.Text) {
					'ja-JP' { $settingBox.Text = '日本語' }
					'en-US' { $settingBox.Text = 'English' }
					default { $settingBox.Text = $script:msg.SettingDefault }
				}
			}
			switch ($settingBox.Text) {
				'$true' { $settingBox.Text = $script:msg.SettingTrue }
				'$false' { $settingBox.Text = $script:msg.SettingFalse }
			}
		} elseif ($settingAttribute -in $undefAttributes) { $settingBox.Text = $script:msg.SettingUndefined }
		else { $settingBox.Text = $script:msg.SettingDefault }
	}
	# 動作停止設定の抽出
	$scheduleStopPattern = '\$script:stopSchedule\s*=\s*@\{([^}]*)\}'
	try {
		$scheduleStopDetail = [RegEx]::Match($userSettings, $scheduleStopPattern)
		# 抽出した内容を解析してチェックボックスに反映
		if ($scheduleStopDetail.Success) {
			$scheduleStopString = $scheduleStopDetail.Groups[1].Value
			foreach ($day in $days) {
				if ($scheduleStopString -match "'$day'\s*=\s*@\(([^)]*)\)") {
					$schedule = $matches[1].Split(',').Trim().where({ $_ })
					foreach ($hour in $schedule) {
						$checkbox = $settingWindow.FindName(('chkbxStop{0}{1}' -f $day, ([Int]$hour).ToString('D2')))
						if ($checkbox) { $checkbox.IsChecked = $true }
					}
				}
			}
		}
	} catch { return }
	Remove-Variable -Name undefAttributes, userSettings, settingBox -ErrorAction SilentlyContinue
	Remove-Variable -Name scheduleStopPattern, scheduleStopDetail, scheduleStopString -ErrorAction SilentlyContinue
	Remove-Variable -Name day, schedule, hour, checkbox -ErrorAction SilentlyContinue
}

# user_setting.ps1に各設定項目を書き込む
function Save-UserSetting {
	[OutputType([Void])]
	Param ()
	$newSetting = @()
	$startSegment = '##Start Setting Generated from GUI'
	$endSegment = '##End Setting Generated from GUI'
	# ファイルが無ければ作ればいい
	if (!(Test-Path $userSettingFile)) {
		New-Item -Path $userSettingFile -ItemType File | Out-Null
		$content = Get-Content -LiteralPath $userSettingFile
		$totalLineNum = 0
	} else {
		$content = Get-Content -LiteralPath $userSettingFile -Encoding UTF8
		#自動生成部分の行数を取得
		$totalLineNum = try { $content.Count } catch { 0 }
		$headLineNum = try { ($content | Select-String $startSegment).LineNumber } catch { 0 }
		$tailLineNum = try { $totalLineNum - ($content | Select-String $endSegment).LineNumber } catch { 0 }
	}
	# 自動生成より前の部分
	# 自動生成の開始位置が2行目以降の場合にだけ自動生成よりの前の部分がある
	if ($headLineNum -ge 2 ) { $newSetting += $content[0..$($headLineNum - 2)] }
	# 動作停止設定以外の部分
	$newSetting += $startSegment
	if ($settingAttributes) {
		foreach ($settingAttribute in $settingAttributes) {
			$settingBox = $settingWindow.FindName($settingAttribute.Replace('$script:', ''))
			# 言語設定はラベルから保存値に変える
			if ($settingBox.Name -eq 'preferredLanguage') {
				switch ($settingBox.Text) {
					'日本語' { $settingBox.Text = 'ja-JP' }
					'English' { $settingBox.Text = 'en-US' }
					default { $settingBox.Text = '' }
				}
			}
			switch -wildcard ($settingBox.Text) {
				{ $_ -in '', $script:msg.SettingDefault, $script:msg.SettingUndefined } { break }
				{ $_ -eq $script:msg.SettingTrue } { $newSetting += ('{0} = $true' -f $settingAttribute) ; break }
				{ $_ -eq $script:msg.SettingFalse } { $newSetting += ('{0} = $false' -f $settingAttribute) ; break }
				default {
					if (([Int]::TryParse($settingBox.Text, [Ref]$null)) -or ($settingBox.Text -match '[${}]')) { $newSetting += ('{0} = {1}' -f $settingAttribute, $settingBox.Text) }
					else { $newSetting += ('{0} = ''{1}''' -f $settingAttribute, $settingBox.Text) }
				}
			}
		}
	}
	# 動作停止設定の部分
	$stopSetting = @()
	$stopSetting += '$script:stopSchedule = @{'
	foreach ($day in $days) {
		$stopHoursList = @()
		foreach ($hour in $hours) {
			$checkbox = $settingWindow.FindName(('chkbxStop{0}{1}' -f $day, $hour.ToString('D2')))
			if ($checkbox -and $checkbox.IsChecked) { $stopHoursList += $hour }
		}
		# 停止時間を文字列に変換し、曜日ごとのエントリを作成
		$stopHours = "'{0}' = @({1})" -f $day, ($stopHoursList -join ', ')
		$stopSetting += "`t" + $stopHours
	}
	$stopSetting += '}'
	$newSetting += $stopSetting
	# 自動生成より後の部分
	$newSetting += $endSegment
	if ( $totalLineNum -ne 0 ) {
		try { $newSetting += Get-Content $userSettingFile -Tail $tailLineNum }
		catch { Write-Warning ($script:msg.AutoGenNotDetected) }
	}
	# 改行コードLFを強制 + NFCで出力
	$newSetting.ForEach({ "{0}`n" -f $_ }).Normalize([Text.NormalizationForm]::FormC)  | Out-File -LiteralPath $userSettingFile -Encoding UTF8 -NoNewline
	Remove-Variable -Name newSetting, startSegment, endSegment, content -ErrorAction SilentlyContinue
	Remove-Variable -Name totalLineNum, headLineNum, tailLineNum -ErrorAction SilentlyContinue
	Remove-Variable -Name settingAttribute, settingBox -ErrorAction SilentlyContinue
	Remove-Variable -Name stopSetting, day, hour, checkbox, stopHours -ErrorAction SilentlyContinue
}

# endregion 関数定義

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理

#----------------------------------------------------------------------
# region WPFのWindow設定

try {
	[Xml]$mainXaml = [String](Get-Content -LiteralPath (Join-Path $script:xamlDir 'TVerRecSetting.xaml'))
	$settingWindow = [System.Windows.Markup.XamlReader]::Load(([System.Xml.XmlNodeReader]::new($mainXaml)))
} catch { Throw ($script:msg.GuiBroken) }
# PowerShellのウィンドウを非表示に
Add-Type -Name Window -Namespace Console -MemberDefinition @'
	[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow();
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'@ | Out-Null
[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
# タスクバーのアイコンにオーバーレイ表示
$settingWindow.TaskbarItemInfo.Overlay = ConvertFrom-Base64 $script:iconBase64
$settingWindow.TaskbarItemInfo.Description = $settingWindow.Title
# ウィンドウを読み込み時の処理
$settingWindow.Add_Loaded({ $settingWindow.Icon = $script:iconPath })
# ウィンドウを閉じる際の処理
$settingWindow.Add_Closing({})
# Name属性を持つ要素のオブジェクト作成
foreach ($node in $mainXaml.SelectNodes('//*[@Name]')) { Set-Variable -Name $node.Name -Value $settingWindow.FindName($node.Name) -Scope Script }
# WPFにロゴをロード
$LogoImage.Source = ConvertFrom-Base64 $script:logoBase64
# バージョン表記
$lblVersion.Content = ('Version {0}' -f $script:appVersion)

# GUI部品のラベルを言語別に設定
$lblBasicSetting.Content = $script:msg.lblBasicSetting
$lblAdvancedSetting.Content = $script:msg.lblAdvancedSetting
$btnWiki.Content = $script:msg.btnWiki
$btnCancel.Content = $script:msg.btnCancel
$btnSave.Content = $script:msg.btnSave
# 基本的な設定
$downloadDirHeader.Header = $script:msg.downloadDirHeader
$downloadDirText.Text = $script:msg.downloadDirText
$workDirHeader.Header = $script:msg.workDirHeader
$workDirText.Text = $script:msg.workDirText
$saveDirHeader.Header = $script:msg.saveDirHeader
$saveDirText.Text = $script:msg.saveDirText
# 動作タブ
$tabOperation.Header = $script:msg.tabOperation
$enableMultithreadHeader.Header = $script:msg.enableMultithreadHeader
$enableMultithreadText.Text = $script:msg.enableMultithreadText
$multithreadNumHeader.Header = $script:msg.multithreadNumHeader
$multithreadNumText.Text = $script:msg.multithreadNumText
$disableToastHeader.Header = $script:msg.disableToastHeader
$disableToastText.Text = $script:msg.disableToastText
$maxExecLogLinesHeader.Header = $script:msg.maxExecLogLinesHeader
$maxExecLogLinesText.Text = $script:msg.maxExecLogLinesText
$histRetentionPeriodHeader.Header = $script:msg.histRetentionPeriodHeader
$histRetentionPeriodText.Text = $script:msg.histRetentionPeriodText
$loopCycleHeader.Header = $script:msg.loopCycleHeader
$loopCycleText.Text = $script:msg.loopCycleText
$detailedProgressHeader.Header = $script:msg.detailedProgressHeader
$detailedProgressText.Text = $script:msg.detailedProgressText
$extractDescTextToListHeader.Header = $script:msg.extractDescTextToListHeader
$extractDescTextToListText.Text = $script:msg.extractDescTextToListText
$listGenHistoryCheckHeader.Header = $script:msg.listGenHistoryCheckHeader
$listGenHistoryCheckText.Text = $script:msg.listGenHistoryCheckText
$cleanupDownloadBaseDirHeader.Header = $script:msg.cleanupDownloadBaseDirHeader
$cleanupDownloadBaseDirText.Text = $script:msg.cleanupDownloadBaseDirText
$cleanupSaveBaseDirHeader.Header = $script:msg.cleanupSaveBaseDirHeader
$cleanupSaveBaseDirText.Text = $script:msg.cleanupSaveBaseDirText
$emptyDownloadBaseDirHeader.Header = $script:msg.emptyDownloadBaseDirHeader
$emptyDownloadBaseDirText.Text = $script:msg.emptyDownloadBaseDirText
$updateChannelHeader.Header = $script:msg.updateChannelHeader
$updateChannelText.Text = $script:msg.updateChannelText
# マイページタブ
$tabMypage.Header = $script:msg.tabMypage
$myPlatformUIDHeader.Header = $script:msg.myPlatformUIDHeader
$myPlatformUIDText.Text = $script:msg.myPlatformUIDText
$myPlatformTokenHeader.Header = $script:msg.myPlatformTokenHeader
$myPlatformTokenText.Text = $script:msg.myPlatformTokenText
$myMemberSIDHeader.Header = $script:msg.myMemberSIDHeader
$myMemberSIDText.Text = $script:msg.myMemberSIDText
# ダウンロードタブ
$tabDownload.Header = $script:msg.tabDownload
$parallelDownloadFileNumHeader.Header = $script:msg.parallelDownloadFileNumHeader
$parallelDownloadFileNumText.Text = $script:msg.parallelDownloadFileNumText
$parallelDownloadNumPerFileHeader.Header = $script:msg.parallelDownloadNumPerFileHeader
$parallelDownloadNumPerFileText.Text = $script:msg.parallelDownloadNumPerFileText
$ytdlTimeoutSecHeader.Header = $script:msg.ytdlTimeoutSecHeader
$YtdlTimeoutSecText.Text = $script:msg.YtdlTimeoutSecText
$minDownloadWorkDirCapacityHeader.Header = $script:msg.minDownloadWorkDirCapacityHeader
$minDownloadWorkDirCapacityText.Text = $script:msg.minDownloadWorkDirCapacityText
$minDownloadBaseDirCapacityHeader.Header = $script:msg.minDownloadBaseDirCapacityHeader
$minDownloadBaseDirCapacityText.Text = $script:msg.minDownloadBaseDirCapacityText
$rateLimitHeader.Header = $script:msg.rateLimitHeader
$rateLimitText.Text = $script:msg.rateLimitText
$timeoutSecHeader.Header = $script:msg.timeoutSecHeader
$timeoutSecText.Text = $script:msg.timeoutSecText
$embedSubtitleHeader.Header = $script:msg.embedSubtitleHeader
$embedSubtitleText.Text = $script:msg.embedSubtitleText
$embedMetatagHeader.Header = $script:msg.embedMetatagHeader
$embedMetatagText.Text = $script:msg.embedMetatagText
$sortVideoBySeriesHeader.Header = $script:msg.sortVideoBySeriesHeader
$sortVideoBySeriesText.Text = $script:msg.sortVideoBySeriesText
$sortVideoByMediaHeader.Header = $script:msg.sortVideoByMediaHeader
$sortVideoByMediaText.Text = $script:msg.sortVideoByMediaText
$forceSingleDownloadHeader.Header = $script:msg.forceSingleDownloadHeader
$forceSingleDownloadText.Text = $script:msg.forceSingleDownloadText
$sitemapParseEpisodeOnlyHeader.Header = $script:msg.sitemapParseEpisodeOnlyHeader
$sitemapParseEpisodeOnlyText.Text = $script:msg.sitemapParseEpisodeOnlyText
$downloadWhenEpisodeIdChangedHeader.Header = $script:msg.downloadWhenEpisodeIdChangedHeader
$downloadWhenEpisodeIdChangedText.Text = $script:msg.downloadWhenEpisodeIdChangedText
$VideoContainerFormatHeader.Header = $script:msg.VideoContainerFormatHeader
$videoContainerFormatText.Text = $script:msg.videoContainerFormatText
# 動画ファイル名タブ
$tabVideoFile.Header = $script:msg.tabVideoFile
$addSeriesNameHeader.Header = $script:msg.addSeriesNameHeader
$addSeriesNameText.Text = $script:msg.addSeriesNameText
$addSeasonNameHeader.Header = $script:msg.addSeasonNameHeader
$addSeasonNameText.Text = $script:msg.addSeasonNameText
$addBroadcastDateHeader.Header = $script:msg.addBroadcastDateHeader
$addBroadcastDateText.Text = $script:msg.addBroadcastDateText
$addEpisodeNumberHeader.Header = $script:msg.addEpisodeNumberHeader
$addEpisodeNumberText.Text = $script:msg.addEpisodeNumberText
$removeSpecialNoteHeader.Header = $script:msg.removeSpecialNoteHeader
$removeSpecialNoteText.Text = $script:msg.removeSpecialNoteText
$ytdlNonTVerFileNameHeader.Header = $script:msg.ytdlNonTVerFileNameHeader
$ytdlNonTVerFileNameText.Text = $script:msg.ytdlNonTVerFileNameText
# Ytdl/ffmpegタブ
$tabYtdlFfmpeg.Header = $script:msg.tabYtdlFfmpeg
$btnFfmpegDecodeOptionClear.Content = $script:msg.btnFfmpegDecodeOptionClear
$btnFfmpegDecodeOptionQsv.Content = $script:msg.btnFfmpegDecodeOptionQsv
$btnFfmpegDecodeOptionD3d11.Content = $script:msg.btnFfmpegDecodeOptionD3d11
$btnFfmpegDecodeOptionD3d9.Content = $script:msg.btnFfmpegDecodeOptionD3d9
$btnFfmpegDecodeOptionCuda.Content = $script:msg.btnFfmpegDecodeOptionCuda
$btnFfmpegDecodeOptionVTB.Content = $script:msg.btnFfmpegDecodeOptionVTB
$btnFfmpegDecodeOptionPi4.Content = $script:msg.btnFfmpegDecodeOptionPi4
$btnFfmpegDecodeOptionPi3.Content = $script:msg.btnFfmpegDecodeOptionPi3
$btnYtdlOptionClear.Content = $script:msg.btnYtdlOptionClear
$btnYtdlOption1080.Content = $script:msg.btnYtdlOption1080
$btnYtdlOption720.Content = $script:msg.btnYtdlOption720
$btnYtdlOption480.Content = $script:msg.btnYtdlOption480
$btnYtdlOption360.Content = $script:msg.btnYtdlOption360
$windowShowStyleHeader.Header = $script:msg.windowShowStyleHeader
$windowShowStyleText.Text = $script:msg.windowShowStyleText
$preferredYoutubedlHeader.Header = $script:msg.preferredYoutubedlHeader
$preferredYoutubedlText.Text = $script:msg.preferredYoutubedlText
$ffmpegDecodeOptionHeader.Header = $script:msg.ffmpegDecodeOptionHeader
$ffmpegDecodeOptionText.Text = $script:msg.ffmpegDecodeOptionText
$forceSoftwareDecodeFlagHeader.Header = $script:msg.forceSoftwareDecodeFlagHeader
$forceSoftwareDecodeFlagText.Text = $script:msg.forceSoftwareDecodeFlagText
$simplifiedValidationHeader.Header = $script:msg.simplifiedValidationHeader
$simplifiedValidationText.Text = $script:msg.simplifiedValidationText
$disableValidationHeader.Header = $script:msg.disableValidationHeader
$disableValidationText.Text = $script:msg.disableValidationText
$disableUpdateYoutubedlHeader.Header = $script:msg.disableUpdateYoutubedlHeader
$disableUpdateYoutubedlText.Text = $script:msg.disableUpdateYoutubedlText
$disableUpdateFfmpegHeader.Header = $script:msg.disableUpdateFfmpegHeader
$disableUpdateFfmpegText.Text = $script:msg.disableUpdateFfmpegText
$ytdlOptionHeader.Header = $script:msg.ytdlOptionHeader
$ytdlOptionText.Text = $script:msg.ytdlOptionText
$ytdlHttpHeaderHeader.Header = $script:msg.ytdlHttpHeaderHeader
$ytdlHttpHeaderText.Text = $script:msg.ytdlHttpHeaderText
$ytdlBaseArgsHeader.Header = $script:msg.ytdlBaseArgsHeader
$ytdlBaseArgsText.Text = $script:msg.ytdlBaseArgsText
$nonTVerYtdlBaseArgsHeader.Header = $script:msg.nonTVerYtdlBaseArgsHeader
$nonTVerYtdlBaseArgsText.Text = $script:msg.nonTVerYtdlBaseArgsText
# Geo IPタブ
$tabGeoIP.Header = $script:msg.tabGeoIP
$proxyUrlHeader.Header = $script:msg.proxyUrlHeader
$proxyUrlText.Text = $script:msg.proxyUrlText
$ytdlRandomIpHeader.Header = $script:msg.ytdlRandomIpHeader
$ytdlRandomIpText.Text = $script:msg.ytdlRandomIpText
# スケジュールタブ
$tabSchedule.Header = $script:msg.tabSchedule
$scheduleStopHeader.Header = $script:msg.scheduleStopHeader
$scheduleStopText.Text = $script:msg.scheduleStopText
$scheduleSpecify.Text = $script:msg.scheduleSpecify
$scheduleStopTime.Text = $script:msg.scheduleStopTextTime
$scheduleStopWeek.Text = $script:msg.scheduleStopTextWeek
$scheduleStopMon.Text = $script:msg.scheduleStopTextMon
$scheduleStopTue.Text = $script:msg.scheduleStopTextTue
$scheduleStopWed.Text = $script:msg.scheduleStopTextWed
$scheduleStopThu.Text = $script:msg.scheduleStopTextThu
$scheduleStopFri.Text = $script:msg.scheduleStopTextFri
$scheduleStopSat.Text = $script:msg.scheduleStopTextSat
$scheduleStopSun.Text = $script:msg.scheduleStopTextSun
$scheduleStopDay.Text = $script:msg.scheduleStopTextDay
# 言語タブ
$tabLanguage.Header = $script:msg.tabLanguage
$preferredLanguageHeader.Header = $script:msg.preferredLanguageHeader
$preferredLanguageText.Text = $script:msg.preferredLanguageText

# ComboBOxのラベルを言語別に設定
$trueFalseOptions = @($script:msg.SettingDefault, $script:msg.SettingTrue, $script:msg.SettingFalse)
foreach ($option in $trueFalseOptions) { $enableMultithread.Items.Add($option) | Out-Null }
foreach ($option in $trueFalseOptions) { $disableToastNotification.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $detailedProgress.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $extractDescTextToList.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $listGenHistoryCheck.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $cleanupDownloadBaseDir.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $cleanupSaveBaseDir.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $emptyDownloadBaseDir.Items.Add($option)  | Out-Null }
$updateChannel.Items.Add($script:msg.SettingDefault) | Out-Null
$updateChannel.Items.Add('release') | Out-Null
$updateChannel.Items.Add('prerelease') | Out-Null
$updateChannel.Items.Add('master') | Out-Null
$updateChannel.Items.Add('beta') | Out-Null
$updateChannel.Items.Add('dev') | Out-Null
foreach ($option in $trueFalseOptions) { $embedSubtitle.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $embedMetatag.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $sortVideoBySeries.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $sortVideoByMedia.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $forceSingleDownload.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $sitemapParseEpisodeOnly.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $downloadWhenEpisodeIdChanged.Items.Add($option)  | Out-Null }
$videoContainerFormat.Items.Add($script:msg.SettingDefault) | Out-Null
$videoContainerFormat.Items.Add('mp4') | Out-Null
$videoContainerFormat.Items.Add('ts') | Out-Null
foreach ($option in $trueFalseOptions) { $addSeriesName.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $addSeasonName.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $addBroadcastDate.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $addEpisodeNumber.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $removeSpecialNote.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $forceSoftwareDecodeFlag.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $simplifiedValidation.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $disableValidation.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $disableUpdateYoutubedl.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $disableUpdateFfmpeg.Items.Add($option)  | Out-Null }
$windowShowStyle.Items.Add($script:msg.SettingDefault) | Out-Null
$windowShowStyle.Items.Add('Minimized') | Out-Null
$windowShowStyle.Items.Add('Hidden') | Out-Null
$windowShowStyle.Items.Add('Normal') | Out-Null
$windowShowStyle.Items.Add('Maximized') | Out-Null
$preferredYoutubedl.Items.Add($script:msg.SettingDefault) | Out-Null
$preferredYoutubedl.Items.Add('yt-dlp') | Out-Null
$preferredYoutubedl.Items.Add('yt-dlp-nightly') | Out-Null
$preferredYoutubedl.Items.Add('ytdl-patched') | Out-Null
foreach ($option in $trueFalseOptions) { $ytdlRandomIp.Items.Add($option)  | Out-Null }
foreach ($option in $trueFalseOptions) { $scheduleStop.Items.Add($option)  | Out-Null }
$preferredLanguage.Items.Add($script:msg.SettingDefault) | Out-Null
$preferredLanguage.Items.Add('日本語') | Out-Null	# ja-JP
$preferredLanguage.Items.Add('English') | Out-Null	# en-US

# endregion WPFのWindow設定
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# region ボタンのアクション
$btnWiki.Add_Click({ Start-Process‘https://github.com/dongaba/TVerRec/wiki’ })
$btnCancel.Add_Click({ $settingWindow.close() })
$btnSave.Add_Click({ Save-UserSetting ; $settingWindow.close() })
$btnDownloadBaseDir.Add_Click({ Select-Folder $script:msg.SelectDownloadDir $script:downloadBaseDir })
$btnDownloadWorkDir.Add_Click({ Select-Folder $script:msg.SelectWorkDir $script:downloadWorkDir })
$btnSaveBaseDir.Add_Click({ Select-Folder $script:msg.SelectSaveDir $script:saveBaseDir })

$btnFfmpegDecodeOptionClear.Add_Click({ $ffmpegDecodeOption.Text = '' })
$btnFfmpegDecodeOptionQsv.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel qsv -c:v h264_qsv' })
$btnFfmpegDecodeOptionD3d11.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel d3d11va -hwaccel_output_format d3d11' })
$btnFfmpegDecodeOptionD3d9.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel dxva2 -hwaccel_output_format dxva2_vld' })
$btnFfmpegDecodeOptionCuda.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel cuda -hwaccel_output_format cuda' })
$btnFfmpegDecodeOptionVTB.Add_Click({ $ffmpegDecodeOption.Text = '-hwaccel videotoolbox' })
$btnFfmpegDecodeOptionPi4.Add_Click({ $ffmpegDecodeOption.Text = '-c:v h264_v4l2m2m -num_output_buffers 32 -num_capture_buffers 32' })
$btnFfmpegDecodeOptionPi3.Add_Click({ $ffmpegDecodeOption.Text = '-c:v h264_omx' })

function Set-YtdlOption ($height) {
	$ytdlOption.Text = if ($height -eq 'Clear') { '' }
	else { '-f "bv[height<=' + $height + ']+ba/b[height<=' + $height + ']"' }
}
$btnYtdlOptionClear.Add_Click({ Set-YtdlOption 'Clear' })
$btnYtdlOption1080.Add_Click({ Set-YtdlOption 1080 })
$btnYtdlOption720.Add_Click({ Set-YtdlOption 720 })
$btnYtdlOption480.Add_Click({ Set-YtdlOption 480 })
$btnYtdlOption360.Add_Click({ Set-YtdlOption 360 })

function Sync-MultiCheckboxes {
	param (
		[String]$day,
		[String]$hour,
		[Object]$allCheckbox
	)
	if ($day) {
		foreach ($hour in $hours) {
			$checkboxName = 'chkbxStop{0}{1:D2}' -f $day, [Int]$hour
			(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			if ($allCheckbox.IsChecked -eq $false) {
				$checkboxName = 'chkbxStop{0:D2}{1}' -f [Int]$hour, 'All'
				(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			}
		}
	} elseif ($hour) {
		foreach ($day in $days) {
			$checkboxName = 'chkbxStop{0}{1:D2}' -f $day, [Int]$hour
			(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			if ($allCheckbox.IsChecked -eq $false) {
				$checkboxName = 'chkbxStop{0}{1}' -f $day, 'All'
				(Get-Variable -Name $checkboxName).Value.IsChecked = $allCheckbox.IsChecked
			}
		}
	}
}

# 各曜日に対してクリックイベントを登録
$chkbxStopMonAll.Add_Click({ Sync-MultiCheckboxes -day 'Mon' -allCheckbox $chkbxStopMonAll })
$chkbxStopTueAll.Add_Click({ Sync-MultiCheckboxes -day 'Tue' -allCheckbox $chkbxStopTueAll })
$chkbxStopWedAll.Add_Click({ Sync-MultiCheckboxes -day 'Wed' -allCheckbox $chkbxStopWedAll })
$chkbxStopThuAll.Add_Click({ Sync-MultiCheckboxes -day 'Thu' -allCheckbox $chkbxStopThuAll })
$chkbxStopFriAll.Add_Click({ Sync-MultiCheckboxes -day 'Fri' -allCheckbox $chkbxStopFriAll })
$chkbxStopSatAll.Add_Click({ Sync-MultiCheckboxes -day 'Sat' -allCheckbox $chkbxStopSatAll })
$chkbxStopSunAll.Add_Click({ Sync-MultiCheckboxes -day 'Sun' -allCheckbox $chkbxStopSunAll })

# 各時間に対してクリックイベントを登録
$chkbxStop00All.Add_Click({ Sync-MultiCheckboxes -hour '00' -allCheckbox $chkbxStop00All })
$chkbxStop01All.Add_Click({ Sync-MultiCheckboxes -hour '01' -allCheckbox $chkbxStop01All })
$chkbxStop02All.Add_Click({ Sync-MultiCheckboxes -hour '02' -allCheckbox $chkbxStop02All })
$chkbxStop03All.Add_Click({ Sync-MultiCheckboxes -hour '03' -allCheckbox $chkbxStop03All })
$chkbxStop04All.Add_Click({ Sync-MultiCheckboxes -hour '04' -allCheckbox $chkbxStop04All })
$chkbxStop05All.Add_Click({ Sync-MultiCheckboxes -hour '05' -allCheckbox $chkbxStop05All })
$chkbxStop06All.Add_Click({ Sync-MultiCheckboxes -hour '06' -allCheckbox $chkbxStop06All })
$chkbxStop07All.Add_Click({ Sync-MultiCheckboxes -hour '07' -allCheckbox $chkbxStop07All })
$chkbxStop08All.Add_Click({ Sync-MultiCheckboxes -hour '08' -allCheckbox $chkbxStop08All })
$chkbxStop09All.Add_Click({ Sync-MultiCheckboxes -hour '09' -allCheckbox $chkbxStop09All })
$chkbxStop10All.Add_Click({ Sync-MultiCheckboxes -hour '10' -allCheckbox $chkbxStop10All })
$chkbxStop11All.Add_Click({ Sync-MultiCheckboxes -hour '11' -allCheckbox $chkbxStop11All })
$chkbxStop12All.Add_Click({ Sync-MultiCheckboxes -hour '12' -allCheckbox $chkbxStop12All })
$chkbxStop13All.Add_Click({ Sync-MultiCheckboxes -hour '13' -allCheckbox $chkbxStop13All })
$chkbxStop14All.Add_Click({ Sync-MultiCheckboxes -hour '14' -allCheckbox $chkbxStop14All })
$chkbxStop15All.Add_Click({ Sync-MultiCheckboxes -hour '15' -allCheckbox $chkbxStop15All })
$chkbxStop16All.Add_Click({ Sync-MultiCheckboxes -hour '16' -allCheckbox $chkbxStop16All })
$chkbxStop17All.Add_Click({ Sync-MultiCheckboxes -hour '17' -allCheckbox $chkbxStop17All })
$chkbxStop18All.Add_Click({ Sync-MultiCheckboxes -hour '18' -allCheckbox $chkbxStop18All })
$chkbxStop19All.Add_Click({ Sync-MultiCheckboxes -hour '19' -allCheckbox $chkbxStop19All })
$chkbxStop20All.Add_Click({ Sync-MultiCheckboxes -hour '20' -allCheckbox $chkbxStop20All })
$chkbxStop21All.Add_Click({ Sync-MultiCheckboxes -hour '21' -allCheckbox $chkbxStop21All })
$chkbxStop22All.Add_Click({ Sync-MultiCheckboxes -hour '22' -allCheckbox $chkbxStop22All })
$chkbxStop23All.Add_Click({ Sync-MultiCheckboxes -hour '23' -allCheckbox $chkbxStop23All })

# endregion ボタンのアクション
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# region 設定ファイルの読み込み
Read-UserSetting
# endregion 設定ファイルの読み込み
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# ウィンドウ表示

try {
	$settingWindow.Show() | Out-Null
	$settingWindow.Activate() | Out-Null
	[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
} catch { Throw ($script:msg.WindowRenderError) }

# メインウィンドウ取得
$currentProcess = [Diagnostics.Process]::GetCurrentProcess()
$form = [Windows.Forms.NativeWindow]::new()
$form.AssignHandle($currentProcess.MainWindowHandle)

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ウィンドウ表示後のループ処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#----------------------------------------------------------------------
# region ウィンドウ表示後のループ処理
while ($settingWindow.IsVisible) {
	# GUIイベント処理
	Sync-WpfEvents
	Start-Sleep -Milliseconds 10
}

# endregion ウィンドウ表示後のループ処理
#----------------------------------------------------------------------

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 終了処理
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Remove-Variable -Name mainXaml, settingWindow -ErrorAction SilentlyContinue
Remove-Variable -Name LogoImage, lblVersion -ErrorAction SilentlyContinue
Remove-Variable -Name btnWiki, btnCancel, btnSave -ErrorAction SilentlyContinue
Remove-Variable -Name btndownloadBaseDir, btnDownloadWorkDir, btnSaveBaseDir -ErrorAction SilentlyContinue
Remove-Variable -Name userSettingFile, settingAttributes -ErrorAction SilentlyContinue
Remove-Variable -Name currentProcess, form -ErrorAction SilentlyContinue
