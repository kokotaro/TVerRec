#!/bin/bash

###################################################################################
#  TVerRec : TVerダウンローダ
#
#		ダウンロード対象外番組削除処理スクリプト
#
###################################################################################

echo -en "\033];TVerRec Video File Deleter\007"

pwsh -NoProfile "../src/delete_trash.ps1"

echo "Completed ..."
