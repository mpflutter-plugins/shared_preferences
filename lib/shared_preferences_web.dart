// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show json;
// ignore: import_of_legacy_library_into_null_safe
import 'package:mpcore/mpjs/mpjs.dart' as js;

import './shared_preferences_platform_interface.dart';

/// The web implementation of [SharedPreferencesStorePlatform].
///
/// This class implements the `package:shared_preferences` functionality for the web.
class SharedPreferencesStore extends SharedPreferencesStorePlatform {
  String miniprogramScope = 'wx';
  bool? isMiniProgram;

  Future<bool> checkIsMiniProgram() async {
    if (isMiniProgram != null) {
      return isMiniProgram!;
    } else {
      if (await js.context.hasProperty('wx')) {
        isMiniProgram = true;
        miniprogramScope = 'wx';
      } else if (await js.context.hasProperty('swan')) {
        isMiniProgram = true;
        miniprogramScope = 'swan';
      } else if (await js.context.hasProperty('my')) {
        isMiniProgram = true;
        miniprogramScope = 'my';
      } else {
        isMiniProgram = false;
      }
      return isMiniProgram!;
    }
  }

  @override
  Future<bool> clear() async {
    for (String key in await _storedFlutterKeys) {
      if (await checkIsMiniProgram()) {
        js.context[miniprogramScope].callMethod('removeStorageSync', [key]);
      } else {
        js.context['localStorage'].callMethod('removeItem', [key]);
      }
    }
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    final isMiniProgram = await checkIsMiniProgram();
    final Map<String, Object> allData = {};
    for (String key in await _storedFlutterKeys) {
      if (isMiniProgram) {
        allData[key] = _decodeValue(await js.context[miniprogramScope]
            .callMethod('getStorageSync', [key]));
        continue;
      }
      allData[key] = _decodeValue(
          await js.context['localStorage'].callMethod('getItem', [key]));
    }
    return allData;
  }

  @override
  Future<bool> remove(String key) async {
    final isMiniProgram = await checkIsMiniProgram();
    _checkPrefix(key);
    if (isMiniProgram) {
      await js.context[miniprogramScope].callMethod('removeStorageSync', [key]);
      return true;
    }
    js.context['localStorage'].callMethod('removeItem', [key]);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object? value) async {
    final isMiniProgram = await checkIsMiniProgram();
    _checkPrefix(key);
    if (isMiniProgram) {
      await js.context[miniprogramScope]
          .callMethod('setStorageSync', [key, _encodeValue(value)]);
      return true;
    }
    await js.context['localStorage']
        .callMethod('setItem', [key, _encodeValue(value)]);
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

  Future<Iterable<String>> get _storedFlutterKeys async {
    final isMiniProgram = await checkIsMiniProgram();
    if (isMiniProgram) {
      final resObject =
          await js.context[miniprogramScope].callMethod('getStorageInfoSync');
      final resJSON =
          await js.context['JSON'].callMethod('stringify', [resObject]);
      final resDartObject = json.decode(resJSON);
      final keys = resDartObject['keys'];
      return keys
          .whereType<String>()
          .where((it) => (it as String).startsWith('flutter.'));
    }
    final resObject = await js.context['Object'].callMethod(
        'keys', [await js.context.getPropertyValue('localStorage')]);
    final resJSON =
        await js.context['JSON'].callMethod('stringify', [resObject]);
    final resDartObject = json.decode(resJSON);
    final keys = resDartObject;
    return keys
        .whereType<String>()
        .where((it) => (it as String).startsWith('flutter.'));
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
