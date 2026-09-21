// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// `Http2Client` is `@experimental` upstream; the `^3.1.0` pin bounds the risk.
// ignore_for_file: experimental_member_use

part of '../app.dart';

/// Routes `https` requests over a pooled HTTP/2 transport and everything
/// else over plain HTTP/1.1.
///
/// googleapis_auth sends more than Firebase's own API calls through the
/// `baseClient` it is handed. Credential negotiation can target plain
/// `http` endpoints that speak no HTTP/2 at all: Application Default
/// Credentials on GCE and Cloud Run fetch tokens from
/// `http://metadata.google.internal`, and an external-account
/// (WIF/OIDC) `credential_source` commonly points at a link-local
/// metadata address. [Http2Client] rejects a non-`https` URL outright, so
/// those requests need a transport of their own.
@internal
class Http2WithHttp1FallbackClient extends BaseClient {
  Http2WithHttp1FallbackClient({Http2Client? http2, Client? http1})
    : _http2 = http2 ?? Http2Client(),
      _http1 = http1;

  final Http2Client _http2;

  Client? _http1;

  @override
  Future<StreamedResponse> send(BaseRequest request) =>
      request.url.scheme == 'https'
      ? _http2.send(request)
      : (_http1 ??= Client()).send(request);

  @override
  void close() {
    _http2.close();
    _http1?.close();
  }
}
