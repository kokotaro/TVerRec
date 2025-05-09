###################################################################################
#
#		GUIメインスクリプト
#
###################################################################################
<#
	.SYNOPSIS
		TVerRecのGUIメインスクリプト

	.DESCRIPTION
		TVerRecのグラフィカルユーザーインターフェース（GUI）を提供するメインスクリプトです。
		Windows Presentation Foundation (WPF)を使用してGUIを構築し、以下の機能を提供します：
		- 単一番組のダウンロード
		- 一括ダウンロード
		- ダウンロードリストの生成と管理
		- 番組の削除と移動
		- 設定の管理

	.NOTES
		前提条件:
		- Windows環境で実行する必要があります
		- PowerShell 7.0以上を推奨です
		- WPFアセンブリが必要です

		主な機能:
		1. GUIの初期化と表示
		2. ユーザーイベントの処理
		3. バックグラウンドジョブの管理
		4. ログ出力の管理

	.EXAMPLE
		# スクリプトを実行してGUIを起動
		.\gui_main.ps1

	.OUTPUTS
		System.Void
		GUIウィンドウを表示し、ユーザーの操作に応じて各種処理を実行します。
#>

using namespace System.Windows.Threading
Set-StrictMode -Version Latest
if (!$IsWindows) { throw ('❌️ Windows以外では動作しません。For Windows only') ; Start-Sleep 10 }
Add-Type -AssemblyName PresentationFramework | Out-Null

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#region 環境設定

try {
	if ($myInvocation.MyCommand.CommandType -ne 'ExternalScript') { $script:scriptRoot = Convert-Path . }
	else { $script:scriptRoot = Split-Path -Parent -Path $myInvocation.MyCommand.Definition }
	$script:scriptRoot = Convert-Path (Join-Path $script:scriptRoot '../')
	Set-Location $script:scriptRoot
} catch { throw '❌️ カレントディレクトリの設定に失敗しました。Failed to set current directory.' }
if ($script:scriptRoot.Contains(' ')) { throw '❌️ TVerRecはスペースを含むディレクトリに配置できません。TVerRec cannot be placed in directories containing space' }
. (Convert-Path (Join-Path $script:scriptRoot '../src/functions/initialize.ps1'))

# パラメータ設定
$jobTerminationStates = @('Completed', 'Failed', 'Stopped')
$msgTypesColorMap = @{
	Output      = 'DarkSlateGray'
	Error       = 'Crimson'
	Warning     = 'Coral'
	Verbose     = 'LightSlateGray'
	Debug       = 'CornflowerBlue'
	Information = 'DarkGray'
}

# ログ出力用変数
$jobMsgs = @()
$msgTypes = @('Output', 'Error', 'Warning', 'Verbose', 'Debug', 'Information')
$msgError = New-Object System.Collections.Generic.List[String]
$msgWarning = New-Object System.Collections.Generic.List[String]
$msgVerbose = New-Object System.Collections.Generic.List[String]
$msgDebug = New-Object System.Collections.Generic.List[String]
$msgInformation = New-Object System.Collections.Generic.List[String]

#endregion 環境設定

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#region 関数定義

# GUIイベントの処理
function Sync-WpfEvents {
	<#
		.SYNOPSIS
			WPFのイベントを同期的に処理します。

		.DESCRIPTION
			WPFのイベントディスパッチャーを使用して、GUIイベントを同期的に処理します。
			これにより、UIの応答性を維持しながらイベントを処理することができます。

		.OUTPUTS
			System.Void

		.NOTES
			この関数は内部で使用され、直接呼び出すことは想定されていません。
	#>
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

# 最大行数以上の実行ログをクリア
function Limit-LogLine {
	<#
		.SYNOPSIS
			ログの行数を制限します。

		.DESCRIPTION
			指定された最大行数を超えるログエントリを削除します。
			これにより、メモリ使用量を制御し、パフォーマンスを維持します。

		.PARAMETER richTextBox
			ログを表示するRichTextBoxコントロール

		.PARAMETER limit
			保持する最大行数

		.OUTPUTS
			System.Void

		.EXAMPLE
			Limit-LogLine -richTextBox $outText -limit 1000
	#>
	[OutputType([Void])]
	Param (
		[parameter(Mandatory = $true)]$richTextBox,
		[parameter(Mandatory = $true)]$limit
	)
	if ($richTextBox.Document.Blocks.Count -gt $limit) {
		$linesToRemove = $richTextBox.Document.Blocks.Count - $limit
		for ($i = 0 ; $i -lt $linesToRemove ; $i++) { $richTextBox.Document.Blocks.Remove($richTextBox.Document.Blocks.FirstBlock) | Out-Null }
	}
	Remove-Variable -Name richTextBox, limit, linesToRemove, i -ErrorAction SilentlyContinue
}

# テキストボックスへのログ出力と再描画
function Out-ExecutionLog {
	<#
		.SYNOPSIS
			実行ログをテキストボックスに出力します。

		.DESCRIPTION
			指定されたメッセージをテキストボックスに出力し、メッセージタイプに応じて色分けを行います。
			ログの最大行数を超えた場合は、古いログを自動的に削除します。

		.PARAMETER message
			出力するメッセージ

		.PARAMETER type
			メッセージのタイプ（Output, Error, Warning, Verbose, Debug, Information）

		.OUTPUTS
			System.Void

		.EXAMPLE
			Out-ExecutionLog -message "処理が完了しました" -type "Output"
	#>
	[OutputType([Void])]
	Param (
		[parameter(Mandatory = $false)][String]$message = '',
		[parameter(Mandatory = $false)][String]$type = 'Output'
	)
	if ($script:guiMaxExecLogLines -gt 0) { Limit-LogLine $outText $script:guiMaxExecLogLines }
	$rtfRange = [System.Windows.Documents.TextRange]::new($outText.Document.ContentEnd, $outText.Document.ContentEnd)
	if ($type -eq 'Output') { $rtfRange.Text = ("{0}`n" -f $Message) }
	else { $rtfRange.Text = ("{0}: {1}`n" -f $type, $Message) }
	$rtfRange.ApplyPropertyValue([System.Windows.Documents.TextElement]::ForegroundProperty, $msgTypesColorMap[$type] )
	$outText.ScrollToEnd()
	Remove-Variable -Name message, type, rtfRange -ErrorAction SilentlyContinue
}

#endregion 関数定義

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# メイン処理

#----------------------------------------------------------------------
#region WPFのWindow設定

try {
	[Xml]$mainXaml = [String](Get-Content -LiteralPath (Join-Path $script:xamlDir 'TVerRecMain.xaml'))
	$mainWindow = [System.Windows.Markup.XamlReader]::Load(([System.Xml.XmlNodeReader]::new($mainXaml)))
} catch { throw ($script:msg.GuiBroken) }
# PowerShellのウィンドウを非表示に
Add-Type -Name Window -Namespace Console -MemberDefinition @'
	[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow();
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'@ | Out-Null
[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
# タスクバーのアイコンにオーバーレイ表示
$mainWindow.TaskbarItemInfo.Overlay = ConvertFrom-Base64 $script:iconBase64
$mainWindow.TaskbarItemInfo.Description = $mainWindow.Title
# ウィンドウを読み込み時の処理
$mainWindow.Add_Loaded({ $mainWindow.Icon = $script:iconPath })
# ウィンドウを閉じる際の処理
$mainWindow.Add_Closing({ Get-Job | Receive-Job -Wait -AutoRemoveJob -Force })
# Name属性を持つ要素のオブジェクト作成
foreach ($node in $mainXaml.SelectNodes('//*[@Name]')) { Set-Variable -Name $node.Name -Value $mainWindow.FindName($node.Name) -Scope Script }
# WPFにロゴをロード
$LogoImage.Source = ConvertFrom-Base64 $script:logoBase64
# バージョン表記
$lblVersion.Content = ('Version {0}' -f $script:appVersion)
# ログ出力するためのテキストボックス
$outText = $mainWindow.FindName('tbOutText')

# GUI部品のラベルを言語別に設定
$lblTool.Content = $script:msg.lblTool
$lblLink.Content = $script:msg.lblLink
$lblLog.Content = $script:msg.lblLog
$btnLoop.Content = $script:msg.btnLoop
$btnSingle.Content = $script:msg.btnSingle
$btnBulk.Content = $script:msg.btnBulk
$btnListGen.Content = $script:msg.btnListGen
$btnList.Content = $script:msg.btnList
$btnDelete.Content = $script:msg.btnDelete
$btnValidate.Content = $script:msg.btnValidate
$btnMove.Content = $script:msg.btnMove
$btnKillAll.Content = $script:msg.btnKillAll
$btnWorkOpen.Content = $script:msg.btnWorkOpen
$btnDownloadOpen.Content = $script:msg.btnDownloadOpen
$btnSaveOpen.Content = $script:msg.btnSaveOpen
$btnKeywordOpen.Content = $script:msg.btnKeywordOpen
$btnIgnoreOpen.Content = $script:msg.btnIgnoreOpen
$btnListOpen.Content = $script:msg.btnListOpen
$btnClearLog.Content = $script:msg.btnClearLog
$btnWiki.Content = $script:msg.btnWiki
$btnSetting.Content = $script:msg.btnSetting
$btnExit.Content = $script:msg.btnExit

#endregion WPFのWindow設定

#----------------------------------------------------------------------
#region バックグラウンドジョブ化する処理を持つボタン

$btns = @(
	$mainWindow.FindName('btnSingle'), #0
	$mainWindow.FindName('btnBulk'), #1
	$mainWindow.FindName('btnListGen'), #2
	$mainWindow.FindName('btnList'), #3
	$mainWindow.FindName('btnDelete'), #4
	$mainWindow.FindName('btnValidate'), #5
	$mainWindow.FindName('btnMove'), #6
	$mainWindow.FindName('btnLoop')
)

# バックグラウンドジョブ化するボタンの処理内容
$scriptBlocks = @{
	$btns[0] = { & './download_single.ps1' $true }
	$btns[1] = { & './download_bulk.ps1' $true }
	$btns[2] = { & './generate_list.ps1' $true }
	$btns[3] = { & './download_list.ps1' $true }
	$btns[4] = { & './delete_trash.ps1' $true }
	$btns[5] = { & './validate_video.ps1' $true }
	$btns[6] = { & './move_video.ps1' $true }
	$btns[7] = { & './loop.ps1' $true }
}

# バックグラウンドジョブ化する処理の名前
# $script:msgに定義されているメッセージを取得するためのキーを引用符なしで指定
$threadNames = @{
	$btns[0] = { ProcessBulkDownload }
	$btns[1] = { ProcessSingleDownload }
	$btns[2] = { ProcessListGenerate }
	$btns[3] = { ProcessListDownload }
	$btns[4] = { ProcessDelete }
	$btns[5] = { ProcessValidate }
	$btns[6] = { ProcessMove }
	$btns[7] = { ProcessLoop }
}

# バックグラウンドジョブ化するボタンのアクション
foreach ($btn in $btns) {
	$btn.Add_Click({
			#ジョブの稼働中はボタンを無効化
			foreach ($btn in $btns) { $btn.IsEnabled = $false }
			$btnExit.IsEnabled = $false
			$lblStatus.Content = $script:msg.(([String]$threadNames[$this]).trim())
			#処理停止ボタンの有効化
			$btnKillAll.IsEnabled = $true
			#バックグラウンドジョブの起動
			Start-ThreadJob -Name $this.Name -ScriptBlock $scriptBlocks[$this] | Out-Null
		})
}

#endregion バックグラウンドジョブ化する処理を持つボタン

#----------------------------------------------------------------------
#region ジョブ化しないボタンのアクション

$btnWorkOpen.Add_Click({ Invoke-Item $script:downloadWorkDir })
$btnDownloadOpen.Add_Click({ Invoke-Item $script:downloadBaseDir })
$btnsaveOpen.Add_Click({
		if ($script:saveBaseDir) { $script:saveBaseDir.Split(';').Trim().ForEach{ Invoke-Item $_ } }
		else { [System.Windows.MessageBox]::Show($script:msg.SaveDirNotSpecified) }
	})
$btnKeywordOpen.Add_Click({ Invoke-Item $script:keywordFilePath })
$btnIgnoreOpen.Add_Click({ Invoke-Item $script:ignoreFilePath })
$btnListOpen.Add_Click({ Invoke-Item $script:listFilePath })
$btnClearLog.Add_Click({
		$script:jobMsgs = @()
		foreach ($msgType in $msgTypes) { Clear-Variable -Name ('msg' + $msgType) }
		$outText.Document.Blocks.Clear()
		Invoke-GarbageCollection
	})
$btnKillAll.Add_Click({
		Get-Job | Remove-Job -Force
		foreach ($btn in $btns) { $btn.IsEnabled = $true }
		$btnExit.IsEnabled = $true; $btnKillAll.IsEnabled = $false
		$lblStatus.Content = $script:msg.ProcessForceStopped
		Invoke-GarbageCollection
	})
$btnWiki.Add_Click({ Start-Process ‘https://github.com/dongaba/TVerRec/wiki’ })
$btnSetting.Add_Click({
		& 'gui/gui_setting.ps1'
		if ( Test-Path (Join-Path $script:confDir 'user_setting.ps1') ) { . (Convert-Path (Join-Path $script:confDir 'user_setting.ps1')) }
		Invoke-GarbageCollection
	})
$btnExit.Add_Click({ $mainWindow.close() })

#endregion ジョブ化しないボタンのアクション

#----------------------------------------------------------------------
#region ウィンドウ表示

# 処理停止ボタンの初期値は無効
$btnKillAll.IsEnabled = $false
try {
	$mainWindow.Show() | Out-Null
	$mainWindow.Activate() | Out-Null
	[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
} catch { throw ($script:msg.WindowRenderError) }

#endregion ウィンドウ表示

#----------------------------------------------------------------------
#region ウィンドウ表示後のループ処理
while ($mainWindow.IsVisible) {
	if ($jobs = Get-Job) {
		# ジョブがある場合の処理
		foreach ($job in $jobs) {
			# 各メッセージタイプごとに内容を取得(ただしReceive-Jobは次Stepで実行するので取りこぼす可能性あり)
			foreach ($msgType in $msgTypes) { Set-Variable -Name ('msg' + $msgType) -Value $(if ($job.$msgType) { $job.$msgType } else { $null }) }
			$jobMsgs = @(Receive-Job $job *>&1)
			# Jobからメッセージを取得し事前に取得したメッセージタイプと照合し色付け
			foreach ($jobMsg in $jobMsgs) {
				$logType = switch ($jobMsg) {
					{ $msgError -contains $_ } { 'Error' ; break }
					{ $msgWarning -contains $_ } { 'Warning' ; break }
					{ $msgVerbose -contains $_ } { 'Verbose' ; break }
					{ $msgDebug -contains $_ } { 'Debug' ; break }
					{ $msgInformation -contains $_ } { 'Information' ; break }
					Default { 'Output' }
				}
				Out-ExecutionLog -Message ($jobMsg -join "`n") -Type $logType
			}
			# 各メッセージタイプごとの内容を保存する変数をクリア
			foreach ($msgType in $msgTypes) { Clear-Variable -Name ('msg' + $msgType) }
			# 終了したジョブのボタンの再有効化
			if ($job.State -in $jobTerminationStates) {
				Remove-Job $job
				$btns.ForEach({ $_.IsEnabled = $true }); $btnExit.IsEnabled = $true; $btnKillAll.IsEnabled = $false
				$lblStatus.Content = $script:msg.ProcessCompleted
				Invoke-GarbageCollection
			}
		}
	}
	# GUIイベント処理
	Sync-WpfEvents
	Start-Sleep -Milliseconds 10
}

#endregion ウィンドウ表示後のループ処理

#----------------------------------------------------------------------
#region 終了処理

# Windowが閉じられたら乗っているゴミジョブを削除して終了
Get-Job | Receive-Job -Wait -AutoRemoveJob -Force

Remove-Variable -Name jobTerminationStates, msgTypesColorMap -ErrorAction SilentlyContinue
Remove-Variable -Name jobMsgs, msgTypes, msgError, msgWarning, msgVerbose, msgDebug, msgInformation -ErrorAction SilentlyContinue
Remove-Variable -Name mainXaml, mainWindow -ErrorAction SilentlyContinue
Remove-Variable -Name LogoImage, lblVersion, outText -ErrorAction SilentlyContinue
Remove-Variable -Name btnBulk, btnDelete, btnList, btnListGen, btnLoop, btnMove, btnSingle, btnValidate, btnExit, btnKillAll -ErrorAction SilentlyContinue
Remove-Variable -Name btns, scriptBlocks, threadNames, btn, lblStatus -ErrorAction SilentlyContinue
Remove-Variable -Name btnWorkOpen, btnDownloadOpen, btnsaveOpen, btnKeywordOpen, btnIgnoreOpen, btnListOpen -ErrorAction SilentlyContinue
Remove-Variable -Name btnClearLog, btnKillAll, btnWiki, btnSetting, btnExit -ErrorAction SilentlyContinue
Remove-Variable -Name jobs, job, msgType, jobMsg, logType -ErrorAction SilentlyContinue

#endregion 終了処理
