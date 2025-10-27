library amap_flutter_base;

import 'dart:ui' show Offset;
import 'package:flutter/material.dart';
import 'dart:math';

part 'src/amap_api_key.dart';
part 'src/amap_tools.dart';
part 'src/callbacks.dart';
part 'src/location.dart';
part 'src/poi.dart';
part 'src/amap_utils.dart';
part 'src/amap_privacy_statement.dart';

int hashValues(
  Object? arg1,
  Object? arg2, [
  Object? arg3,
  Object? arg4,
  Object? arg5,
  Object? arg6,
  Object? arg7,
  Object? arg8,
  Object? arg9,
  Object? arg10,
]) {
  return Object.hashAll(<Object?>[
    arg1,
    arg2,
    arg3,
    arg4,
    arg5,
    arg6,
    arg7,
    arg8,
    arg9,
    arg10,
  ]);
}
