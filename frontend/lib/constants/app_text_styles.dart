import 'package:flutter/material.dart';

/// Gaya teks khusus emoji. Sengaja tidak menetapkan `fontFamily` agar bentuk
/// emoji mengikuti font bawaan perangkat (Noto di Android, Apple Color Emoji
/// di iOS), sehingga terasa native di masing-masing HP.
TextStyle emojiStyle({double size = 18}) {
  return TextStyle(fontSize: size);
}
