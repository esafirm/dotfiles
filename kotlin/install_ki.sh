#!/usr/bin/env bash

cd $BIN

download_link="https://search.maven.org/remotecontent?filepath=org/jetbrains/kotlinx/ki-shell/0.3.2/ki-shell-0.3.2-archive.zip"
zip_file="ki.zip"

wget -O $zip_file $download_link

unzip $zip_file -d $BIN