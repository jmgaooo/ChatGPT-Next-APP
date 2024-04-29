import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:path/path.dart' as path;

final rand = Random();
int portMin = 1024;
int portMax = 65535;
WebUri serverAddr = WebUri("http://localhost:8080");
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
    await extractArchiveToDisk(archive, appDocDir.path);
  }

  var pipe = const Pipeline();
  if (kDebugMode) {
    pipe.addMiddleware(logRequests());
  }
  var handler = pipe.addHandler(
      createStaticHandler(webDir.path, defaultDocument: 'index.html'));

  late HttpServer server;
  for (int i = 0; i < 5; i++) {
    try {
      server = await shelf_io.serve(handler, serverAddr.host, serverAddr.port);
      break;
    } on SocketException catch (e) {
      print(e);
      int port = portMin + rand.nextInt(portMax - portMin);
      serverAddr = WebUri("http://localhost:$port");
    }
  }
  // Enable content compression
  server.autoCompress = true;
  print('Serving at http://${server.address.host}:${server.port}');
  runApp(NextChat());
}

class NextChat extends StatelessWidget {
  NextChat({super.key});
  late InAppWebViewController webViewController;
  final ValueNotifier<bool> showBackBtn = ValueNotifier<bool>(false);

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
          body: Stack(
            children: [
              InAppWebView(
                  initialUrlRequest: URLRequest(url: serverAddr),
                  initialSettings:
                      InAppWebViewSettings(useOnDownloadStart: true),
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                  },
                  onPageCommitVisible: (controller, url) {
                    print("onPageCommitVisible: ${url}");
                    if (url!.host == serverAddr.host) {
                      showBackBtn.value = false;
                    } else {
                      showBackBtn.value = true;
                    }
                  },
                  //导出数据
                  onDownloadStartRequest: (controller, url) async {
                    if (url.url.scheme == "data") {
                      String? outputFile = await FilePicker.platform.saveFile(
                          dialogTitle: 'Please select an output file:',
                          fileName:
                              'nextchat_${DateTime.now().microsecondsSinceEpoch}.txt',
                          bytes: url.url.data!.contentAsBytes());
                      print("outputFile: $outputFile");
                    }
                  }),
              Positioned(
                  bottom: 20,
                  left: 20,
                  child: ValueListenableBuilder(
                      valueListenable: showBackBtn,
                      builder: (context, value, child) {
                        if (value) {
                          return IconButton(
                            iconSize: 50,
                            color: Colors.blue,
                            onPressed: () {
                              webViewController.goBack();
                            },
                            icon: const Icon(Icons.arrow_circle_left_outlined),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }))
            ],
          ),
        ));
  }
}
