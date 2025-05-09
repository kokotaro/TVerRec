###################################################################################
#
#		システム設定
#
###################################################################################
#----------------------------------------------------------------------
#	「#」or「;」でコメントアウト
#	このファイルに書かれた内容はそのままPowershellスクリプトとして実行。
#----------------------------------------------------------------------
Set-StrictMode -Version Latest
$InformationPreference = 'Continue'

#----------------------------------------------------------------------
#	基本的な設定
#----------------------------------------------------------------------

# ダウンロード先のフルパス(絶対パス指定)
#　ダウンロード先とは、ダウンロードが終わった動画ファイルが配置される場所です。
#　例えばC:\Users\yamada-taro\Videoにダウンロードするのであれば
#　$script:downloadBaseDir = 'C:\Users\yamada-taro\Video' と設定します。
#　MacOSやLinuxでは $script:downloadBaseDir = '/mnt/Work' や
#　$script:downloadBaseDir = '/Volumes/Work' などのように設定します。
$script:downloadBaseDir = ''

# ダウンロード中の作業ディレクトリのフルパス(絶対パス指定)
#　作業ディレクトリは、動画のダウンロード中に処理途中のファイルが配置される場所です。
#　多数のファイルが作成され読み書きが多発するので、SSDやRamDriveなどの
#　高速なディスクを指定すると動作速度が向上します。
#　例えばC:\Tempにダウンロードするのであれば $script:downloadWorkDir = 'C:\Temp' と設定します。
#　MacOSやLinuxでは $script:downloadWorkDir = '/var/tmp' や
#　$script:downloadWorkDir = '/Volumes/RamDrive/Temp' などのように設定します。
$script:downloadWorkDir = ''

# 移動先のフルパス(絶対パス指定)
#　移動先とは、動画ファイルを最終的に整理するためのライブラリ等が配置されている場所です。
#　規定の設定では設定されていません。
#　ダウンロード先のディレクトリで動画を再生するのであれば、指定しなくてもOKです。
#　例えばC:\TverLibraryを移動先にするのであれば
#　$script:saveBaseDir = 'C:\TverLibrary' と設定します。
#　複数のディレクトリを移動先として指定する場合には
#　$script:saveBaseDir = 'V:;X:' のようにセミコロン区切りで複数指定可能です。
#　ただし、複数のディレクトリに同名のディレクトリがある場合には、先に指定したディレクトリが優先されます。
#　MacOSやLinuxでは $script:saveBaseDir = '/var/Video' や
#　$script:saveBaseDir = '/Volumes/RamDrive/Video' などのように設定します。
$script:saveBaseDir = ''

#----------------------------------------------------------------------
#	高度な設定
#----------------------------------------------------------------------

# 同時ダウンロードファイル数
#　同時に並行でダウンロードする番組の数を設定します。
#　ここの数字を増やすことで同時ダウンロード数を増やすことはできますが、
#　PCへの負荷が高まり逆にダウンロード効率が下がるのでご注意ください。
$script:parallelDownloadFileNum = 5

# 番組あたりの同時ダウンロード数
#　それぞれの番組をダウンロードする際の並行ダウンロード数を設定します。
#　ここの数字を増やすことで同時ダウンロード数を増やすことはできますが、
#　PCへの負荷が高まり逆にダウンロード効率が下がるのでご注意ください。
$script:parallelDownloadNumPerFile = 10

# youtube-dlのタイムアウト時間(秒)
#　たまにyoutube-dlのプロセスがフリーズしてしまうことがあり、
#　永遠にyoutube-dlの終了を待ち続けてしまうことがあります。
#　ここで設定した時間内にそれぞれのyoutube-dlのプロセスが完了しない場合に強制終了させることができます。
#　0を設定するとタイムアウトしないようになります。
$script:ytdlTimeoutSec = 0

# 作業フォルダの最低容量(MB)
#　作業フォルダの容量が少ないときに処理を中断するための設定です。
#　ダウンロード開始時点で作業フォルダが設定値を下回った場合にダウンロードを中断します。
#　0を設定する中断しないようになります。
$script:minDownloadWorkDirCapacity = 1000

# ダウンロード先フォルダの最低容量(MB)
#　ダウンロード先フォルダの容量が少ないときに処理を中断するための設定です。
#　ダウンロード開始時点でダウンロード先フォルダ容量が設定値を下回った場合にダウンロードを中断します。
#　0を設定する中断しないようになります。
$script:minDownloadBaseDirCapacity = 1000

# ループ処理の間隔(秒)
#　ループ処理の実行間隔を指定します。
$script:loopCycle = 3600

# マイページ処理用UIDとToken(TVerを匿名で利用する場合)
#　TVerIDを登録しない状態で、マイページに登録したお気に入りやあとでみる、続きから再生などを
#　TVerRecでダウンロードするためのplatform_uidとplatform_tokenを指定します。
#　TVerIDを登録しないで利用する場合、これを指定しないとマイページ配下の番組はダウンロードできません。
#　platform_uidとplatform_tokenはブラウザの開発者ツール、またはChrome拡張機能TVerRec Assistantを使って確認できます。
#　詳細はWiKiの[platform_uid、platform_token、member_sidの取得]を参照してください。
$script:myPlatformUID = ''
$script:myPlatformToken = ''

# マイページ処理用memberSID(TVerをユーザ登録して利用する場合)
#　TVerIDを登録した状態で、マイページに登録したお気に入りやあとでみる、続きから再生などを
#　TVerRecでダウンロードするためのmember_sidを指定します。
#　TVerIDを登録した状態でマイページに保存した番組をダウンロードするには、これを指定しないとダウンロードできません。
#　memberSIDはブラウザの開発者ツール、またはChrome拡張機能TVerRec Assistantを使って確認できるようになる予定です。
#　詳細はWiKiの[platform_uid、platform_token、member_sidの取得]を参照してください。
$script:myMemberSID = ''

# 並列処理の有効化
#　並列処理を有効化して処理を高速化するかを設定します。
#　ただし、並列処理を有効化すると履歴ファイルやダウンロード対象外リストの破損リスクが高まります。
#　現在のところ、並列処理を行うのはダウンロードリストの作成処理とダウンロード対象外番組の削除処理、
#　空ディレクトリの削除処理です。
$script:enableMultithread = $true

# 並列処理の同時スレッド数
#　PCの性能に応じて適度に設定してください。
#　最近のPCであれば50くらいの値を設定しても十分に動作すると思います。
#　あまり大きな数を指定すると逆に処理時間が長くなる可能性があります。
#　現在のところ、理並列処理を行うのはダウンロード対象外の番組削除と空ディレクトリの削除処理です。
$script:multithreadNum = 10

# トースト通知の無効化
#　トースト通知を無効化することが可能です。
$script:disableToastNotification = $false

# ダウンロード帯域制限
#　ネットワーク帯域を使い切らないようにダウンロード速度制限を設定することができます。
#　単位はMbpsです。
#　0を設定すると帯域制限をしません。
$script:rateLimit = 0

# HTTPアクセスのタイムアウト(sec)
#　各種HTTPのアクセス時のタイムアウト値(秒)です。
#　設定した時間以内にHTTPの応答がなければエラーとして判断されます。
$script:timeoutSec = 60

# GUI版の最大ログ行数
#　GUI版で実行ログの最大行数を制限することができます。
#　実行ログの行数が増えてくるとメモリ使用量の増大やレスポンスが低下する可能性が高いです。
#　規定の設定では1000行に設定されています。
#　0に設定することで無制限とすることができます。
$script:guiMaxExecLogLines = 1000

# ダウンロード履歴保持日数
#　ダウンロード履歴を保持する日数を指定します。
#　保持期間を長くすると、同じ番組の再配信があった際に重複ダウンロードしなくて済む可能性が高くなりますが、
#　処理時間が長くなる可能性があります。
$script:histRetentionPeriod = 30

# 番組ディレクトリ配下にダウンロードファイルを保存
#　番組ごとのディレクトリを作って番組をダウンロードするかを設定します。
#　「$false」の際の移動先は以下
#　  ダウンロード先/
#　    └番組シリーズ名 番組シーズン名 放送日 番組タイトル名.mp4
#　「$true」の際の移動先は以下
#　  ダウンロード先/
#　    └番組シリーズ名 番組シーズン名/
#　      └番組シリーズ名 番組シーズン名 放送日 番組タイトル名.mp4
#　※厳密にはファイル名は他のオプションによって決定されます
$script:sortVideoBySeries = $true

# 放送局毎のディレクトリ配下にダウンロードファイルを保存
#　放送局(テレビ局)ごとのディレクトリを作って番組をダウンロードするかを設定します。
#　「$false」の際の移動先は以下
#　  ダウンロード先/
#　    └番組シリーズ名 番組シーズン名/
#　      └番組シリーズ名 番組シーズン名 放送日 番組タイトル名.mp4
#　「$true」の際の移動先は以下
#　  ダウンロード先/
#　    └放送局/
#　      └番組シリーズ名 番組シーズン名/
#　        └番組シリーズ名 番組シーズン名 放送日 番組タイトル名.mp4
#　※厳密にはファイル名は他のオプションによって決定されます
$script:sortVideoByMedia = $false

# ダウンロードファイル名に番組シリーズ名を付加
#　「$false」の場合のファイル名は以下
#　  番組シーズン名 放送日Epエピソード番号 番組タイトル名.mp4
#　「$true」の際のファイル名は以下
#　  番組シリーズ名 番組シーズン名 放送日Epエピソード番号 番組タイトル名.mp4
#　※厳密にはファイル名は他のオプションによって決定されます
$script:addSeriesName = $true

# ダウンロードファイル名に番組シーズン名を付加
#　「$false」の場合のファイル名は以下
#　  番組シリーズ名 放送日Epエピソード番号 番組タイトル名.mp4
#　「$true」の際のファイル名は以下
#　  番組シリーズ名 番組シーズン名 放送日Epエピソード番号 番組タイトル名.mp4
#　※厳密にはファイル名は他のオプションによって決定されます
$script:addSeasonName = $true

# ダウンロードファイル名に番組放送日を付加
#　「$false」の場合のファイル名は以下
#　  番組シリーズ名 番組シーズン名Epエピソード番号 番組タイトル名.mp4
#　「$true」の際のファイル名は以下
#　  番組シリーズ名 番組シーズン名 放送日Epエピソード番号 番組タイトル名.mp4
#　※厳密にはファイル名は他のオプションによって決定されます
$script:addBroadcastDate = $true

# ダウンロードファイル名にエピソード番号を付加
#　「$false」の場合のファイル名は以下
#　  番組シリーズ名 番組シーズン名 放送日 番組タイトル名.mp4
#　「$true」の際のファイル名は以下
#　  番組シリーズ名 番組シーズン名 放送日Epエピソード番号 番組タイトル名.mp4
#　※厳密にはファイル名は他のオプションによって決定されます
$script:addEpisodeNumber = $true

# 番組名に付くことがある不要なコメントを削除
#　「$false」の場合はTVerで配信されているとおりに番組名を設定
#　「$true」の場合は「《」と「》」、「【」と「】」で挟まれた部分を削除
#　《ドラマ特区》、《新シリーズ放送記念》、《ドラマParavi》、《〇〇出演 「〇〇」スタート記念》などを除去する目的
#　「《」と「》」、「【」と「】」で挟まれた部分が10文字以下の場合は削除されません
$script:removeSpecialNote = $true

# 番組ファイルへの字幕データの埋め込み
#　ダウンロードしたファイルに字幕データを埋め込むかを設定します。
#　字幕データが提供されていない番組も多くありますのでご注意ください。
$script:embedSubtitle = $true

# 番組ファイルへのメタタグの埋め込み
#　ダウンロードしたファイルにメタタグを埋め込むかを設定します。
$script:embedMetatag = $true

# youtube-dlの取得元
#　youtube-dlに起因する問題(例えばダウンロードできないなど)が起きた際には2種類のyoutube-dlを使い分けることが可能です。
#　'yt-dlp'を設定するとyt-dlp(https://github.com/yt-dlp/yt-dlp)から取得します。
#　'ytdl-patched'を設定するとytdl-patched(https://github.com/ytdl-patched/ytdl-patched)から取得します。
$script:preferredYoutubedl = 'yt-dlp'

# youtube-dlの自動アップデートを無効化
#　youtube-dlの配布元の不具合等により自動アップデートがうまく動作しない場合には無効化することが可能です。
$script:disableUpdateYoutubedl = $false

# ffmpegの自動アップデートを無効化
#　ffmpegの配布元の不具合等により自動アップデートがうまく動作しない場合には無効化することが可能です。
$script:disableUpdateFfmpeg = $false

# ソフトウェアデコードの強制(「$true」でソフトウェアデコードの強制。ただしCPU使用率が上がる)
#　ダウンロードファイルの整合性検証時にハードウェアアクセラレーションを使わなくすることができます。
#　高速なCPUが搭載されている場合はハードウェアアクセラレーションよりもCPUで処理したほうが処理が早いことがあります。
#　概ね10世代以降のIntel Core CPUであれば、GPUを搭載していてもソフトウェアデコードの方が高速です。
#　Apple Silicon搭載のMacでもソフトウェアデコードのほうが高速です。
$script:forceSoftwareDecodeFlag = $false

# 番組の整合性検証の高速化
#　番組検証を簡素化するかどうかを設定します。
#　簡素化した場合、ffmpegによる番組の完全検証ではなく、ffprobeによる簡易検証に切り替えます。
#　番組1本あたり数秒で検証が完了しますが、検証精度は低いです。(おそらくメタデータの検査だけの模様)
$script:simplifiedValidation = $false

# 番組の整合性検証の無効化
$script:disableValidation = $false

# サイトマップ処理時にエピソードのみ処理
#　キーワードファイルでサイトマップ指定をした際にエピソードのみを処理するかどうかを設定します。
#　現在のところ、エピソードだけの処理でもすべての番組動画が含まれているようなので、
#　エピソードだけの処理でも全番組のダウンロードが可能なようです。
#　処理時間が長くなりますが、エピソード以外も処理することでダウンロード対象番組が増える可能性があります。
$script:sitemapParseEpisodeOnly = $true

# エピソードID変更時の再ダウンロード
#　エピソードIDが変更された際に再ダウンロードするかを設定します。
#　同一番組(保存ファイル名が同一ファイル名になる番組)でもエピソードIDが変更になることがあります。
#　どのような場合にエピソードIDが変更されるのかはよくわかりませんが、字幕データの追加や配信内容が変更されている可能性があります。
#　「$true」の場合はエピソードID変更時に番組動画を再ダウンロードします。
#　「$false」の場合はエピソードID変更時に番組動画を再ダウンロードしません。
$script:downloadWhenEpisodeIdChanged = $true

# youtube-dlとffmpegのウィンドウの表示方法(Windowsのみ) Normal/Maximized/Minimized/Hidden
#　youtube-dlとffmpegのウィンドウをどのように表示するかを設定します。
#　Minimizedに設定することで最小化状態でウィンドウが作成されるようになり必要なときにだけ進捗確認をすることができます。
#　Hiddenに設定すると非表示となります。
#　Normalに設定すると多数のウィンドウが表示され鬱陶しいのでおすすめしません。
#　Maximizedに設定すると最大化した状態でウィンドウが表示されますが、通常利用では利用することはないと思います。
$script:windowShowStyle = 'Minimized'

# ffmpegのデコードオプション
#　直接ffmpegのオプションを記載することができます。
#　ダウンロードファイルの整合性検証時にハードウェアアクセラレーションを有効化する際などに使用します。
#　例えばIntel CPUを搭載した一般的なPCであれば、-hwaccel qsv -c:v h264_qsvを設定することで、CPU内蔵のアクセラレータを使ってCPU負荷を下げつつ高速に処理することが可能です。
#　この設定はソフトウェアデコードの強制を有効に設定されていると無効化されます。
$script:ffmpegDecodeOption = ''

# 以下は$script:ffmpegDecodeOptionの設定例
#	QSV : for Intel CPUs (Intel内蔵グラフィックを使用)
#	$script:ffmpegDecodeOption = '-hwaccel qsv -c:v h264_qsv'
#	Direct3D 11 : for Windows (GPUを使用)
#	$script:ffmpegDecodeOption = '-hwaccel d3d11va -hwaccel_output_format d3d11'
#	Direct3D 9 : for Windows (GPUを使用)
#	$script:ffmpegDecodeOption = '-hwaccel dxva2 -hwaccel_output_format dxva2_vld'
#	CUDA : for NVIDIA Graphic Cards
#	$script:ffmpegDecodeOption = '-hwaccel cuda -hwaccel_output_format cuda'
#	VideoToolbox : for Macs
#	$script:ffmpegDecodeOption = '-hwaccel videotoolbox'
#	for Raspberry Pi 4 64bit
#	$script:ffmpegDecodeOption = '-c:v h264_v4l2m2m -num_output_buffers 32 -num_capture_buffers 32'
#	for Raspberry Pi 3/4 32bit
#	$script:ffmpegDecodeOption = '-c:v h264_omx'

# youtube-dlオプション
#　直接youtube-dlのオプションを記載することができます。
#　動画の解像度を指定する場合などに使用します。
#　ここで設定した内容はTVer以外のサイトにも適用されます。
$script:ytdlOption = ''

# 以下は$script:ytdlOptionの設定例
#	1080p
#	$script:ytdlOption = '-f "bv[height<=1080]+ba/b[height<=1080]"'
#	720p
#	$script:ytdlOption = '-f "bv[height<=720]+ba/b[height<=720]"'
#	480p
#	$script:ytdlOption = '-f "bv[height<=480]+ba/b[height<=480]"'
#	360p
#	$script:ytdlOption = '-f "bv[height<=360]+ba/b[height<=360]"'

# ダウンロード時にのランダムIPアドレス使用
#　youtube-dlはデフォルトで固定の日本のIPアドレスを使用しますが、動画のダウンロード時にTVerRecが生成したランダムの日本のIPアドレスを使用することができます。
#　IPアドレスによるBANの可能性を低減できるかもしれません。
#　ここで設定した内容はTVer以外のサイトにも適用されます。
#　「$true」の場合は起動ごとに生成されるランダムIPアドレスを使用します。
#　「$false」の場合はyoutube-dlのデフォルト機能を使用します。
$script:ytdlRandomIp = $false

# Tverサイト以外のベースファイル名
$script:ytdlNonTVerFileName = '%(webpage_url_domain)s - %(upload_date)s - %(title)s - [%(id)s].%(ext)s'

# 個別ダウンロード時の強制ダウンロード
#　個別ダウンロードの際に過去履歴やダウンロード対象外リストとの照合をせずに強制ダウンロードするかを設定します。
#　この設定を有効にすると、不要ファイル削除処理時にダウンロード対象外リストとマッチするディレクトリの削除を行わなくなります。
$script:forceSingleDownload = $false

# ダウンロードリストファイルへの番組説明の出力
#　ダウンロードリストファイルに番組説明情報を出力するかを設定します。
$script:extractDescTextToList = $false

# ダウンロードリスト作成時のダウンロード履歴との突合
#　ダウンロードリストファイル作成時にダウンロード履歴に含まれる番組を除外するかを設定します。
#　「$true」の場合はダウンロード履歴に番組履歴がある際はリストファイルに出力しません。
#　「$false」の場合はダウンロード履歴に番組履歴があってもリストファイルに出力します。
$script:listGenHistoryCheck = $true

# TVerRecのアップデートチャネル
#　TVerRecのアップデータを実行した際に、どのチャネルから最新版をダウンロードするのかを設定します。
#　規定ではreleaseが設定されており、リリース版の最新版をダウンロードします。(プレリリースは除きます)
#　prereleaseに設定すると、プレリリース版の最新版をダウンロードします。(リリース版のほうが新しくても常に一番新しいプレリリース板となるのでご注意ください)
#　masterに設定すると、masterブランチの最新版を取得します。リリース前の機能を先行取得できます。
#　betaに設定すると、betaブランチの最新版を取得します。より新しい機能をお試しいただけますが、ベータ版のため不具合を含んでいる可能性があります。
#　devに設定すると、devブランチの最新版を取得します。開発中の最新機能をお試しいただけますが、安定動作しない可能性があるため特殊要件がなければおすすめしません。
$script:updateChannel = 'release'

# TVer番組ファイルの動画コンテナ形式
#　TVer番組ファイルの動画コンテナ形式を設定します。
#　デフォルトではmp4となっており、メタ情報や字幕、サムネイルなどの埋込はmp4形式のみで有効です。
#　主に音ズレ対策としてts形式を指定することもできますが、ts形式を使うことで音ズレがなくなるかどうかはよくわかりません。
#　ts形式を指定した場合、メタ情報や字幕、サムネイルなどの埋め込みは利用できなくなります。
#　機能に制限が出るため、基本的にはmp4を指定することが推奨で、特段理由がなければtsを指定しない方が良いと思います。
$script:videoContainerFormat = 'mp4'

# 不要ファイル削除時にダウンロードディレクトリのチェック
#　不要ファイル削除時にダウンロードディレクトリもチェック対象にするかを設定します。
#　「$true」の場合はダウンロードディレクトリにあるファイルも削除対象にします。
#　「$false」の場合はダウンロードディレクトリにあるファイルも削除対象にしません。
$script:cleanupDownloadBaseDir = $false

# 不要ファイル削除時に保存のチェック
#　不要ファイル削除時に保存ディレクトリもチェック対象にするかを設定します。
#　「$true」の場合は保存ディレクトリにあるファイルも削除対象にします。
#　「$false」の場合は保存ディレクトリにあるファイルも削除対象にしません。
$script:cleanupSaveBaseDir = $false

# 空ディレクトリ削除時処理を実行するかのチェック
#　不要ファイル削除処理時とファイル移動処理時に空ディレクトリを削除するかを設定します。
#　「$true」の場合は空ディレクトリ削除時処理を実行します。
#　「$false」の場合は空ディレクトリ削除時処理を実行しません。
$script:emptyDownloadBaseDir = $true

# youtube-dlのHTTPヘッダ
#　youtube-dlがHTTPアクセスをする際に追加のHTTPヘッダを指定することができます。
$script:ytdlHttpHeader = 'Accept-Language:ja-JP'

# TVerサイト用youtube-dlの引数
#　TVerサイトからのダウンロード設定です。TVerRecはこの設定が入っていることを前提としているので変更は自己責任でお願いします。
$script:ytdlBaseArgs = ' --verbose --format "(bv*+ba/b)" --force-overwrites --console-title --no-mtime --retries 10 --fragment-retries 10 --abort-on-unavailable-fragment --no-keep-fragments --abort-on-error --no-continue --windows-filenames --no-cache-dir --verbose --no-check-certificates --buffer-size 16K'

# Tverサイト以外youtube-dlの引数
#　TVerサイト以外からのダウンロード設定です。TVerRecはこの設定が入っていることを前提としているので変更は自己責任でお願いします。
$script:nonTVerYtdlBaseArgs = ' --verbose --format "(bv*+ba/b)" --force-overwrites --console-title --no-mtime --retries 10 --fragment-retries 10 --abort-on-unavailable-fragment --no-keep-fragments --abort-on-error --no-continue --windows-filenames --no-cache-dir --verbose --no-check-certificates --buffer-size 16K'


# 進捗情報メッセージの表示
#　キーワード配下の番組一覧取得における進捗情報を表示するかを設定します。
#　処理時間が長く動作停止しているのか処理中なのか判断がつかない場合には、進捗表示をすることで進捗状況をより詳細に出力します。
$script:detailedProgress = $false

# スケジュール設定
#　特定の曜日・時間帯にダウンロード等の処理を停止したい場合に曜日ごとの低時間帯を指定します。（1時間ごと）
#　TVerRecは定期的に停止時間かどうかをチェックし、停止時間では処理を一時停止して待機します。停止時間外になると処理を再開します。
#　仕組み上、処理の停止や再開は厳密には制御できませんので設定されたっ時間は目安としてしてください。
$script:scheduleStop = $false
#　各曜日ごとに停止したい処理を停止したい時間帯をカンマ区切りで24時間指定で指定します。
#　例えば、月曜日の0時〜5:59に停止をしたい場合は、'Mon' = @()の部分を'Mon' = @(0, 1, 2, 3, 4, 5)とします。
$script:stopSchedule = @{
	'Mon' = @()
	'Tue' = @()
	'Wed' = @()
	'Thu' = @()
	'Fri' = @()
	'Sat' = @()
	'Sun' = @()
}

# 言語設定
#　TVerRecはOSの言語設定に基づき自動的に言語を切り替えますが、自動設定がうまくいかない場合は言語設定を強制できます。
#　設定可能な値はresources/lang/mesasges.jsonにエントリがある言語コードで、現時点では｢ja-JP｣と｢en-US｣が設定可能です。
#　何も指定しなければOSの言語設定に基づき自動的に言語が切り替わります。(言語データが無い場合は英語表記となります)
$script:preferredLanguage = ''

# Geo IPチェック回避用Proxy URL
#　TVerではかなり厳しいGeo IPチェックが実施されているため、日本国外から利用することができません。
#　Proxyを使うことがでGeo IPチェックを回避できますが、常にProxyを使用するとダウンロードまで遅くなってしまいます。
#　TVerRecではマニフェスト取得などの本当に必要なときにだけProxyを使用し、動画のダウンロードにはProxyを使用しません。
#　ProxyサーバのURLは「http://123.45.67.89:12345」のフォーマットで指定してください。
#　Proxyを使用しない場合は空白にしておいてください。
$script:proxyUrl = ''


#----------------------------------------------------------------------
#	以下は変更を推奨しない設定。変更の際は自己責任で。
#----------------------------------------------------------------------
# アプリケーション名・バージョン番号
$script:appName = 'TVerRec'
$script:appVersion = Get-Content '../VERSION'

# デバッグレベル
$VerbosePreference = 'SilentlyContinue'						#詳細メッセージなし
$DebugPreference = 'SilentlyContinue'						#デバッグメッセージなし
$PSStyle.Formatting.Error = $PSStyle.Foreground.BrightRed
$PSStyle.Formatting.Warning = $PSStyle.Foreground.BrightYellow
$PSStyle.Formatting.Verbose = $PSStyle.Foreground.BrightBlack
$PSStyle.Formatting.Debug = $PSStyle.Foreground.BrightBlue

# ファイルシステムが許容するファイル名の最大長(byte)
$script:fileNameLengthMax = 255

# 各種ディレクトリのパス
$script:tverrecDir = Convert-Path (Join-Path $scriptRoot '..')
$script:binDir = Convert-Path (Join-Path $scriptRoot '../bin')
$script:dbDir = Convert-Path (Join-Path $scriptRoot '../db')
$script:listDir = Convert-Path (Join-Path $scriptRoot '../db')
$script:logDir = Convert-Path (Join-Path $scriptRoot '../log')
$script:unixDir = Convert-Path (Join-Path $scriptRoot '../unix')
$script:winDir = Convert-Path (Join-Path $scriptRoot '../win')
$script:b64Dir = Convert-Path (Join-Path $scriptRoot '../resources/b64')
$script:imgDir = Convert-Path (Join-Path $scriptRoot '../resources/img')
$script:libDir = Convert-Path (Join-Path $scriptRoot '../resources/lib')
$script:lockDir = Convert-Path (Join-Path $scriptRoot '../resources/lock')
$script:sampleDir = Convert-Path (Join-Path $scriptRoot '../resources/sample')
$script:xamlDir = Convert-Path (Join-Path $scriptRoot '../resources/xaml')
$script:geoIPDir = Convert-Path (Join-Path $scriptRoot '../resources/geoip')
$script:containerDir = Join-Path $scriptRoot '../container-data'

# アイコンを設定
$script:iconBase64 = Get-Content (Join-Path $b64Dir 'Icon.b64')
$script:logoBase64 = Get-Content (Join-Path $b64Dir 'Logo.b64')

# トースト通知用画像のパス
$script:toastAppLogo = Convert-Path (Join-Path $script:imgDir 'TVerRec-Toast.png')

# ウィンドウアイコン用画像のパス
$script:iconPath = Convert-Path (Join-Path $script:imgDir 'TVerRec-Icon.png')
