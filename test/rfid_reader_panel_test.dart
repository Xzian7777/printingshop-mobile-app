import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printingshop/widgets/rfid_reader_panel.dart';

void main() {
  testWidgets('RFID pairing renders on a narrow screen and cancels polling on disposal', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <String>[];
    Future<Map<String, dynamic>> request(String path,
        {String method = 'GET', Map<String, dynamic>? data}) async {
      requests.add(path);
      return {'success': true, 'readers': <Map<String, dynamic>>[]};
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: RfidReaderPanel(request: request)))));
    await tester.pump();
    expect(find.text('USB RFID reader'), findsOneWidget);
    expect(find.text('Connect the paired USB bridge to begin.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    final count = requests.length;
    await tester.pump(const Duration(seconds: 6));
    expect(requests.length, count);
  });
}
