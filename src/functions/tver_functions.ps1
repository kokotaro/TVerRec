###################################################################################
#
#		TVer固有関数スクリプト
#
#	Copyright (c) 2022 dongaba
#
#	Licensed under the MIT License;
#	Permission is hereby granted, free of charge, to any person obtaining a copy
#	of this software and associated documentation files (the "Software"), to deal
#	in the Software without restriction, including without limitation the rights
#	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the Software is
#	furnished to do so, subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be included in
#	all copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#	THE SOFTWARE.
#
###################################################################################
Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

#----------------------------------------------------------------------
#TVerのAPI Tokenを取得
#----------------------------------------------------------------------
function Get-Token () {
	[OutputType([System.Void])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$tverTokenURL = 'https://platform-api.tver.jp/v2/api/platform_users/browser/create'
	$requestHeader = @{
		'Content-Type' = 'application/x-www-form-urlencoded'
	}
	$requestBody = 'device_type=pc'
	try {
		$tokenResponse = Invoke-RestMethod `
			-Uri $tverTokenURL `
			-Method 'POST' `
			-Headers $requestHeader `
			-Body $requestBody `
			-TimeoutSec $script:timeoutSec
		$script:platformUID = $tokenResponse.Result.platform_uid
		$script:platformToken = $tokenResponse.Result.platform_token
	} catch { Write-Warning ('❗ トークン取得エラー、終了します') ; exit 1 }
}

#----------------------------------------------------------------------
#キーワードから番組のリンクへの変換
#----------------------------------------------------------------------
function Get-VideoLinksFromKeyword {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$keyword)

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$script:episodeLinks = @()
	$script:seriesLinks = [System.Collections.Generic.List[String]]::new()

	$key = $keyword.split(' ')[0].split("`t")[0].Split('/')[0]
	$tverID = Remove-Comment(($keyword.Replace("$key/", '')).Trim())
	Invoke-StatisticsCheck -Operation 'search' -TVerType $key -TVerID $tverID
	try {
		switch ($key) {
			'series' { $script:episodeLinks = @(Get-LinkFromSeriesID $tverID) ; continue }
			'talents' { $script:episodeLinks = @(Get-LinkFromTalentID $tverID) ; continue }
			'tag' { $script:episodeLinks = @(Get-LinkFromTag $tverID) ; continue }
			'new' { $script:episodeLinks = @(Get-LinkFromNew $tverID) ; continue }
			'ranking' { $script:episodeLinks = @(Get-LinkFromRanking $tverID) ; continue }
			'toppage' { $script:episodeLinks = @(Get-LinkFromTopPage) ; continue }
			'sitemap' { $script:episodeLinks = @(Get-LinkFromSiteMap) ; continue }
			default { $script:episodeLinks = @(Get-LinkFromFreeKeyword $keyword) }
		}
	} catch { Write-Warning ("❗ 情報取得エラー。スキップします Type:$key") ; continue }

	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#各種IDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function ProcessSearchResults {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)][String]$baseURL,
		[Parameter(Mandatory = $false)][String]$type,
		[Parameter(Mandatory = $false)][String]$keyword
	)

	#URLの整形
	if ($type -eq 'keyword') { $callSearchURL = ('{0}?platform_uid={1}&platform_token={2}&keyword={3}' -f $baseURL, $script:platformUID, $script:platformToken, $keyword) }
	else { $callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $baseURL, $script:platformUID, $script:platformToken) }

	#取得した値をタイプごとに調整
	$searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	if ($type -in @('new', 'ranking')) { $searchResults = $searchResultsRaw.Result.Contents.Contents }
	elseif ($type -eq 'specialmain') { $searchResults = $searchResultsRaw.Result.specialContents }
	elseif ($type -eq 'specialdetail') { $searchResults = $searchResultsRaw.Result.Contents.Content.Contents }
	else { $searchResults = $searchResultsRaw.Result.Contents }

	#タイプ別に再帰呼び出し
	foreach ($searchResult in $searchResults) {
		switch ($searchResult.Type) {
			'live' { continue }
			'episode' {
				$script:episodeLinks += ('https://tver.jp/episodes/{0}' -f $searchResult.Content.Id)
				continue
			}
			'series' {
				Write-Verbose ('　Series {0} からEpisodeを抽出中...' -f $searchResult.Content.Id)
				Get-LinkFromSeriesID $searchResult.Content.Id
				continue
			}
			'season' {
				Write-Verbose ('　Season {0} からEpisodeを抽出中...' -f $searchResult.Content.Id)
				Get-LinkFromSeasonID $searchResult.Content.Id
				continue
			}
			'special' {
				Write-Verbose ('　Special Detail {0} からEpisodeを抽出中...' -f $searchResult.Content.Id)
				Get-LinkFromSpecialDetailID $searchResult.Content.Id
				continue
			}
			default { $script:episodeLinks += ('https://tver.jp/{0}/{1}' -f $searchResult.Type, $searchResult.Content.Id) }
		}
	}

	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#SeriesIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSeriesID {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$seriesID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$script:episodeLinks += @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSeriesSeasons/{0}' -f $seriesID))
	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#SeasonIDによる番組検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSeasonID {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$seasonID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$script:episodeLinks += @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/{0}' -f $seasonID))
	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#TalentIDによるタレント検索から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTalentID {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$talentID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$script:episodeLinks += @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callTalentEpisode/{0}' -f $talentID))
	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#SpecialIDによる特集ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSpecialMainID {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$specialMainID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$script:episodeLinks += @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSpecialContents/{0}' -f $specialMainID) -Type 'specialmain')
	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#SpecialDetailIDによる特集ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSpecialDetailID {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$specialDetailID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$script:episodeLinks += @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/{0}' -f $specialDetailID) -Type 'specialdetail')
	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#タグから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTag {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$tagID)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$script:episodeLinks += @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callTagSearch/{0}' -f $tagID))
	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#新着から番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromNew {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$genre)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$script:episodeLinks += @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callNewerDetail/{0}' -f $genre) -Type 'new')
	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#ランキングから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromRanking {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$genre)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	if ($genre -eq 'all') { $script:episodeLinks += @(ProcessSearchResults -baseURL 'https://platform-api.tver.jp/service/api/v1/callEpisodeRanking' -Type 'ranking') }
	else { $script:episodeLinks += @(ProcessSearchResults -baseURL ('https://platform-api.tver.jp/service/api/v1/callEpisodeRankingDetail/{0}' -f $genre) -Type 'ranking') }
	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#TVerのAPIを叩いてフリーワード検索
#----------------------------------------------------------------------
function Get-LinkFromFreeKeyword {
	[OutputType([System.Object[]])]
	Param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][String]$keyword)
	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)
	$script:episodeLinks += @(ProcessSearchResults -baseURL 'https://platform-api.tver.jp/service/api/v1/callKeywordSearch' -Type 'keyword' -Keyword $keyword)
	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#トップページから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromTopPage {
	[OutputType([System.Object[]])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$callSearchBaseURL = 'https://platform-api.tver.jp/service/api/v1/callHome'
	$callSearchURL = ('{0}?platform_uid={1}&platform_token={2}' -f $callSearchBaseURL, $script:platformUID, $script:platformToken)
	$searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$searchResults = $searchResultsRaw.Result.Components
	foreach ($searchResult in $searchResults) {
		if ($searchResult.Type -in @('horizontal', 'ranking', 'talents', 'billboard', 'episodeRanking', 'newer', 'ender', 'talent', 'special', 'specialContent') ) {
			#横スクロール型 or 総合ランキング or 注目タレント or 特集
			foreach ($searchResultContent in $searchResult.Contents) {
				switch ($searchResultContent.Type) {
					'live' { continue }
					'episode' {
						$script:episodeLinks += ('https://tver.jp/episodes/{0}' -f $searchResultContent.Content.Id)
						continue
					}
					'series' {
						#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
						Write-Verbose ('　Series {0} をバッファに保存中...' -f $searchResultContent.Content.Id)
						$script:seriesLinks.Add($searchResultContent.Content.Id)
						continue
					}
					'season' {
						Write-Verbose ('　Season {0} からEpisodeを抽出中...' -f $searchResultContent.Content.Id)
						Get-LinkFromSeasonID ($searchResultContent.Content.Id)
						continue
					}
					'talent' {
						Write-Verbose ('　Talent {0} からEpisodeを抽出中...' -f $searchResultContent.Content.Id)
						Get-LinkFromTalentID ($searchResultContent.Content.Id)
						continue
					}
					'specialMain' {
						Write-Verbose ('　Special Main {0} からEpisodeを抽出中...' -f $searchResultContent.Content.Id)
						Get-LinkFromSpecialMainID ($searchResultContent.Content.Id)
						continue
					}
					'special' {
						Write-Verbose ('　Special Detail {0} からEpisodeを抽出中...' -f $searchResultContent.Content.Id)
						Get-LinkFromSpecialDetailID ($searchResultContent.Content.Id)
						continue
					}
					default { $script:episodeLinks += ('https://tver.jp/{0}/{1}' -f $searchResultContent.Type, $searchResultContent.Content.Id) }
				}
			}
		} elseif ($searchResult.Type -eq 'topics') {
			foreach ($searchResultContent in $searchResult.Contents) {
				switch ($searchResultContent.Content.Content.Type) {
					'live' { continue }
					'episode' {
						$script:episodeLinks += ('https://tver.jp/episodes/{0}' -f $searchResultContent.Content.Content.Content.Id)
						continue
					}
					'series' {
						#Seriesは重複が多いので高速化のためにバッファにためて最後に処理
						Write-Verbose ('　Series {0} をバッファに保存中...' -f $searchResultContent.Content.Content.Content.Id)
						$script:seriesLinks.Add(($searchResultContent.Content.Content.Content.Id))
						continue
					}
					'season' {
						Write-Verbose ('　Season {0} からEpisodeを抽出中...' -f $searchResultContent.Content.Content.Content.Id)
						Get-LinkFromSeasonID ($searchResultContent.Content.Content.Content.Id)
						continue
					}
					'talent' {
						Write-Verbose ('　Talent {0} からEpisodeを抽出中...' -f $searchResultContent.Content.Content.Content.Id)
						Get-LinkFromTalentID ($searchResultContent.Content.Content.Content.Id)
						continue
					}
					default { $script:episodeLinks += ('https://tver.jp/{0}/{1}' -f $searchResultContent.Content.Content.Type, $searchResultContent.Content.Content.Content.Id) }
				}
			}
		} elseif ($searchResult.Type -eq 'banner') { #広告	URLは $searchResult.Contents.Content.targetURL
		} elseif ($searchResult.Type -eq 'resume') { #続きを見る	ブラウザのCookieを処理しないといけないと思われるため対応予定なし
		} elseif ($searchResult.Type -eq 'favorite') { #お気に入り	ブラウザのCookieを処理しないといけないと思われるため対応予定なし
		} else { Write-Warning ('❗ 未知のパターンです。 - {0}' -f $searchResult.Type) }

	}

	#バッファしておいたSeriesの重複を削除しEpisodeを抽出
	$script:seriesLinks = $script:seriesLinks | Sort-Object -Unique
	foreach ($seriesID in $script:seriesLinks) {
		Write-Verbose ('　Series {0} からEpisodeを抽出中...' -f $seriesID)
		Get-LinkFromSeriesID ($seriesID)
	}

	return $script:episodeLinks | Sort-Object -Unique
}

#----------------------------------------------------------------------
#サイトマップから番組ページのLinkを取得
#----------------------------------------------------------------------
function Get-LinkFromSiteMap {
	[OutputType([System.Object[]])]
	Param ()

	Write-Debug ('{0}' -f $MyInvocation.MyCommand.Name)

	$callSearchURL = 'https://tver.jp/sitemap.xml'
	$searchResultsRaw = Invoke-RestMethod -Uri $callSearchURL -Method 'GET' -Headers $script:requestHeader -TimeoutSec $script:timeoutSec
	$searchResults = $searchResultsRaw.urlset.url.loc | Sort-Object -Unique

	foreach ($searchResult in $searchResults) {
		if ($searchResult -cmatch '\/episodes\/') { $script:episodeLinks += ($searchResult) }
		elseif ($script:sitemapParseEpisodeOnly) { Write-Debug ('Episodeではないためスキップします') }
		else {
			switch ($true) {
				($searchResult -cmatch '\/series\/') {
					Write-Verbose ('　{0} からEpisodeを抽出中...' -f $searchResult)
					try { Get-LinkFromSeriesID $searchResult.Replace('https://tver.jp/series/', '') }
					catch { Write-Warning ('❗ 情報取得エラー。スキップします Err:12') }
					continue
				}
				($searchResult -eq 'https://tver.jp/') { continue }	#トップページ	別のキーワードがあるためため対応予定なし
				($searchResult -cmatch '\/info\/') { continue }	#お知らせ	番組ページではないため対応予定なし
				($searchResult -cmatch '\/live\/') { continue }	#追っかけ再生	対応していない
				($searchResult -cmatch '\/mypage\/') { continue }	#マイページ	ブラウザのCookieを処理しないといけないと思われるため対応予定なし
				($searchResult -cmatch '\/program') { continue }	#番組表	番組ページではないため対応予定なし
				($searchResult -cmatch '\/ranking') { continue }	#ランキング	他でカバーできるため対応予定なし
				($searchResult -cmatch '\/specials') { continue }	#特集	他でカバーできるため対応予定なし
				($searchResult -cmatch '\/topics') { continue }	#トピック	番組ページではないため対応予定なし
				default { Write-Warning ('❗ 未知のパターンです。 - {0}' -f $searchResult) }
			}
		}
	}

	return $script:episodeLinks | Sort-Object -Unique
}
