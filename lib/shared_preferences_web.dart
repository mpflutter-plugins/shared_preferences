// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show json;
import 'dart:html' as html;
import 'dart:js' as js;

import './shared_preferences_platform_interface.dart';

const bool isTaro = bool.fromEnvironment(
  'mpcore.env.taro',
  defaultValue: false,
);

/// The web implementation of [SharedPreferencesStorePlatform].
///
/// This class implements the `package:shared_preferences` functionality for the web.
class SharedPreferencesStore extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() async {
    for (String key in _storedFlutterKeys) {
      if (isTaro) {
        (js.context['Taro'] as js.JsObject)
            .callMethod('removeStorageSync', [key]);
        continue;
      }
      html.window.localStorage.remove(key);
    }
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    final Map<String, Object> allData = {};
    for (String key in _storedFlutterKeys) {
      if (isTaro) {
        allData[key] = _decodeValue((js.context['Taro'] as js.JsObject)
            .callMethod('getStorageSync', [key]));
        continue;
      }
      allData[key] = _decodeValue(html.window.localStorage[key]!);
    }
    return allData;
  }

  @override
  Future<bool> remove(String key) async {
    _checkPrefix(key);
    if (isTaro) {
      (js.context['Taro'] as js.JsObject)
          .callMethod('removeStorageSync', [key]);
      return true;
    }
    html.window.localStorage.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object? value) async {
    _checkPrefix(key);
    if (isTaro) {
      (js.context['Taro'] as js.JsObject)
          .callMethod('setStorageSync', [key, _encodeValue(value)]);
      return true;
    }
    html.window.localStorage[key] = _encodeValue(value);
    return true;
  }

  void _checkPrefix(String key) {
    if (!key.startsWith('flutter.')) {
      throw FormatException(
        'Shared preferences keys must start with prefix "flutter.".',
        key,
        0,
      );
    }
  }

  Iterable<String> get _storedFlutterKeys {
    if (isTaro) {
      final resObject =
          (js.context['Taro'] as js.JsObject).callMethod('getStorageInfoSync');
      final resJSON = (js.context['JSON'] as js.JsObject)
          .callMethod('stringify', [resObject]);
      final resDartObject = json.decode(resJSON);
      final keys = resDartObject['keys'];
      return keys
          .whereType<String>()
          .where((it) => (it as String).startsWith('flutter.'));
    }
    return html.window.localStorage.keys
        .where((key) => key.startsWith('flutter.'));
  }

  String _encodeValue(Object? value) {
    return json.encode(value);
  }

  Object _decodeValue(String encodedValue) {
    final Object decodedValue = json.decode(encodedValue);

    if (decodedValue is List) {
      // JSON does not preserve generics. The encode/decode roundtrip is
      // `List<String>` => JSON => `List<dynamic>`. We have to explicitly
      // restore the RTTI.
      return decodedValue.cast<String>();
    }

    return decodedValue;
  }
}
