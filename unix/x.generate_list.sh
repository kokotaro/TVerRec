#!/bin/bash

###################################################################################
#  TVerRec : TVerダウンローダ
#
#		個別ダウンロードスクリプト
#
###################################################################################

echo -en "\033];TVerRec Video File List Generator\007"

pwsh -NoProfile "../src/generate_list.ps1"

echo "Completed ..."
