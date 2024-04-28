import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:path/path.dart' as path;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var appDocDir = await getApplicationSupportDirectory();
  print("appDocDir:${appDocDir.path}");
  var webDir = Directory(path.join(appDocDir.path, "web"));
  if (!webDir.existsSync()) {
    print("unzip...");
    var data = await rootBundle.load("assets/web.zip");
    final archive =
        ZipDecoder().decodeBuffer(InputStream(data.buffer.asUint8List()));
    extractArchiveToDisk(archive, appDocDir.path);
  }
  
  var handler = const Pipeline().addMiddleware(logRequests()).addHandler(
      createStaticHandler(webDir.path, defaultDocument: 'index.html'));

  var server = await shelf_io.serve(handler, 'localhost', 8080);

  // Enable content compression
  server.autoCompress = true;

  print('Serving at http://${server.address.host}:${server.port}');

  runApp(const NextChat());
}

class NextChat extends StatelessWidget {
  const NextChat({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'NextChat',
        home: Scaffold(
          appBar: AppBar(
            toolbarHeight: 0,
            systemOverlayStyle: const SystemUiOverlayStyle(
                systemNavigationBarColor: Color(0xffe7f8ff)),
          ),
          body: InAppWebView(
              initialUrlRequest:
                  URLRequest(url: WebUri("http://127.0.0.1:8080"))),
        ));
  }
}
