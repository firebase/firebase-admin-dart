@echo off
REM Adapted from google_cloud_pubsub's tool/protoc-gen-dart.bat in
REM https://github.com/googleapis/google-cloud-dart (Apache-2.0).
dart run protoc_plugin %*
