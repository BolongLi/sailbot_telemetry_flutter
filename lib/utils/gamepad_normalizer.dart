// lib/input/gamepad_normalizer.dart

import 'dart:io' show Platform;

class CanonButton {
  final String key;   // canonical key like '6','7', etc.
  final bool pressed; // true = pressed/held, false = released
  final num value;    // raw value (0/1 for buttons, analog for axes)

  CanonButton({
    required this.key,
    required this.pressed,
    required this.value,
  });
}

// Map Android keycodes to your canonical numbers.
// Expand this table to cover all buttons you care about.
String? _androidKeyToCanonical(String androidKey) {
  switch (androidKey) {
    case 'KEYCODE_BUTTON_B': return '3';
    case 'KEYCODE_BUTTON_X': return '1';
    case 'KEYCODE_BUTTON_L1': return '7';
    case 'KEYCODE_BUTTON_R1': return '6';
    case 'KEYCODE_BUTTON_SELECT': return '10';
    case 'KEYCODE_BUTTON_START': return '11';
    case 'AXIS_GAS': return '4';
    case 'AXIS_BRAKE': return '5';
    default: return null;
  }
}

// Normalize raw event data into canonical format
CanonButton? normalizeButton({
  required String rawKey,
  required num rawValue,
}) {
  final bool isAndroid = Platform.isAndroid;

  // 1) map key
  String? canonKey;
  if (isAndroid) {
    canonKey = _androidKeyToCanonical(rawKey);
    if (canonKey == null) return null;
  } else {
    canonKey = rawKey;
  }

  // 2) normalize pressed state
  final bool pressed = isAndroid ? (rawValue == 0) : (rawValue == 1);
  final num value = (rawValue > 1 || rawValue < 0) ? _normalize(rawValue) : rawValue;
  // print("am I android? $isAndroid");
  // print("am I linux? ${Platform.isLinux}");

  return CanonButton(key: canonKey, pressed: pressed, value: value);
}

double _normalize(num raw) {
    // Common cases:
    // - int axis: -32768..32767  (triggers sometimes rest at -32768)
    // - double axis: -1..1 or 0..1
    double v;
    if (raw is int) {
      v = raw / 32767.0; // now ~[-1..1]
    } else {
      v = raw.toDouble(); // assume already normalized
    }

    // If trigger rests near -1 and increases to +1, remap to [0..1]:
    // Adjust this depending on your device—if yours is already [0..1], just return v.
    final vv = ((v + 1.0) / 2.0).clamp(0.0, 1.0);
    return vv;
  }