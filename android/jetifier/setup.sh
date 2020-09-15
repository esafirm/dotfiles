#!/usr/bin/env bash

ZIP_NAME=jetifier.zip

curl "https://dl.google.com/dl/android/studio/jetifier-zips/1.0.0-beta09/jetifier-standalone.zip" -o $ZIP_NAME
unzip $ZIP_NAME
rm -rf $ZIP_NAME

mv jetifier-standalone/bin/jetifier-standalone jetifier-standalone/bin/jetifier
rm jetifier-standalone/bin/jetifier-standalone.bat

echo "Done. jetifier ready"