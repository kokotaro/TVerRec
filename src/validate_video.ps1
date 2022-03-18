###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		動画チェック処理スクリプト
#
#	Copyright (c) 2021 dongaba
#
#	Licensed under the Apache License, Version 2.0 (the "License");
#	you may not use this file except in compliance with the License.
#	You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" BASIS,
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#	See the License for the specific language governing permissions and
#	limitations under the License.
#
###################################################################################
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
try {
	if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') { 
		$currentDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition 
	} else {
		$currentDir = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0]) 
		if (!$currentDir) { $currentDir = '.' } 
	}
	Set-Location $currentDir
	$configDir = $(Join-Path $currentDir '..\config')
	$sysFile = $(Join-Path $configDir 'system_setting.conf')
	$confFile = $(Join-Path $configDir 'user_setting.conf')

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	Get-Content $sysFile | Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression
	Get-Content $confFile | Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. '.\common_functions_5.ps1'
		. '.\tver_functions_5.ps1'
	} else {
		. '.\common_functions.ps1'
		. '.\tver_functions.ps1'
	}
} catch { Write-Host '設定ファイルの読み込みに失敗しました'; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理

$ffmpegDecodeOption = getFfmpegDecodeOption		#ffmpegのハードウェアデコードオプションの設定
purgeDB											#30日以上前に処理したものはリストから削除
uniqueDB										#リストの重複削除

#録画リストからビデオチェックが終わっていないものを読み込み
try {
	$videoLists = Import-Csv $listFile -Encoding UTF8 | `
			Where-Object { $_.videoValidated -ne '1' } | `
			Where-Object { $_.videoPath -ne '-- IGNORED --' } | `
			Select-Object 'videoPath'
} catch { Write-Host 'リストの読み込み更新に失敗しました' ; exit 1 }

if ($null -eq $videoLists) {
	Write-Host '----------------------------------------------------------------------'
	Write-Host 'すべてのビデオをチェック済みです'
	Write-Host '----------------------------------------------------------------------'
} else {
	Write-Host '----------------------------------------------------------------------'
	Write-Host '以下のビデオをチェックします'
	Write-Host '----------------------------------------------------------------------'
	$i = 0
	#----------------------------------------------------------------------
	foreach ($videoList in $videoLists.videoPath) {
		$videoPath = $videoList
		$i = $i + 1
		Write-Host "$i 本目: $videoPath"
	}
	#----------------------------------------------------------------------

	#----------------------------------------------------------------------
	$j = 0
	foreach ($videoList in $videoLists.videoPath) {
		$videoPath = $videoList
		$j = $j + 1
		#保存先ディレクトリの存在確認
		if (Test-Path $downloadBasePath -PathType Container) {}
		else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' ; exit 1 }
		Write-Host "$j/$i 本目をチェック中: $videoPath"
		checkVideo $ffmpegDecodeOption		#ビデオの整合性チェック
	}
	#----------------------------------------------------------------------
}


