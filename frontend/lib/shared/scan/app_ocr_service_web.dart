import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'app_ocr_service.dart';

AppOcrService createPlatformOcrService() => const AppTesseractJsOcrService();

/// Free on-device OCR via Tesseract.js (WASM) loaded from a public CDN.
/// Images stay in-memory; nothing is uploaded to HMS media storage.
final class AppTesseractJsOcrService implements AppOcrService {
  const AppTesseractJsOcrService();

  static Future<void>? _loading;

  @override
  Future<AppOcrResult> recognize(
    Uint8List bytes, {
    String? mimeType,
    String language = 'eng',
  }) async {
    try {
      await _ensureTesseractLoaded();
      final String dataUrl =
          'data:${_mime(mimeType)};base64,${_base64Encode(bytes)}';
      final JSObject? tesseract =
          globalContext.getProperty('Tesseract'.toJS) as JSObject?;
      if (tesseract == null) {
        return const AppOcrResult(text: '');
      }
      final JSAny? promiseAny = tesseract.callMethodVarArgs(
        'recognize'.toJS,
        <JSAny?>[dataUrl.toJS, language.toJS],
      );
      if (promiseAny == null) {
        return const AppOcrResult(text: '');
      }
      final JSAny? result = await (promiseAny as JSPromise<JSAny?>).toDart;
      if (result == null) {
        return const AppOcrResult(text: '');
      }
      final JSObject data =
          (result as JSObject).getProperty('data'.toJS) as JSObject;
      final JSAny? textValue = data.getProperty('text'.toJS);
      final String text = textValue is JSString ? textValue.toDart : '';
      final List<String> lines = text
          .split(RegExp(r'\r?\n'))
          .map((String line) => line.trim())
          .where((String line) => line.isNotEmpty)
          .toList(growable: false);
      return AppOcrResult(text: text.trim(), lines: lines);
    } catch (_) {
      return const AppOcrResult(text: '');
    }
  }

  static Future<void> _ensureTesseractLoaded() {
    final Future<void>? existing = _loading;
    if (existing != null) {
      return existing;
    }
    _loading = () async {
      final JSAny? existing = globalContext.getProperty('Tesseract'.toJS);
      if (existing != null) {
        return;
      }
      final Completer<void> done = Completer<void>();
      final web.HTMLScriptElement script = web.HTMLScriptElement()
        ..src =
            'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js'
        ..async = true;
      script.onload = (web.Event _) {
        if (!done.isCompleted) {
          done.complete();
        }
      }.toJS;
      script.onerror = (web.Event _) {
        if (!done.isCompleted) {
          done.completeError(StateError('Failed to load Tesseract.js'));
        }
      }.toJS;
      web.document.head?.appendChild(script);
      await done.future;
    }();
    return _loading!;
  }

  static String _mime(String? mimeType) {
    final String mime = (mimeType ?? '').trim();
    return mime.isEmpty ? 'image/jpeg' : mime;
  }

  static String _base64Encode(Uint8List bytes) {
    const String chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < bytes.length; i += 3) {
      final int b0 = bytes[i];
      final int b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final int b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      final int triple = (b0 << 16) | (b1 << 8) | b2;
      out.write(chars[(triple >> 18) & 63]);
      out.write(chars[(triple >> 12) & 63]);
      out.write(i + 1 < bytes.length ? chars[(triple >> 6) & 63] : '=');
      out.write(i + 2 < bytes.length ? chars[triple & 63] : '=');
    }
    return out.toString();
  }
}
