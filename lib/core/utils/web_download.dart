import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Helper untuk mengunduh file teks/CSV langsung di peramban (browser) web
void downloadFileWeb({
  required String content,
  required String filename,
  String mimeType = 'text/csv;charset=utf-8;',
}) {
  final bytes = utf8.encode(content);
  final bom = [0xEF, 0xBB, 0xBF];
  final allBytes = Uint8List.fromList([...bom, ...bytes]);

  final blob = web.Blob(
    [allBytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );

  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
