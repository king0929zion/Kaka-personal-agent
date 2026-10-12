import 'package:flutter_test/flutter_test.dart';
import 'package:kaka_flutter/core/api.dart';
import 'package:kaka_flutter/features/computer/computer_screen.dart';

void main(){
  test('remote computer loopback screen URLs use the API host',(){
    final source=Uri.parse('https://kaka.example:8443');
    final url=resolveComputerScreenUri(source,
      'http://127.0.0.1:6080/novnc/session/view/token?view_only=1');
    expect(url.host,'kaka.example');
    expect(url.port,6080);
    expect(url.path,'/novnc/session/view/token');
    expect(url.queryParameters['view_only'],'1');
  });

  test('relative and local URLs retain the correct destination',(){
    final base=Uri.parse('https://kaka.example');
    expect(resolveComputerScreenUri(base,'/novnc/start').toString(),
      'https://kaka.example/novnc/start');
    final local=Uri.parse('http://localhost:8080');
    expect(resolveComputerScreenUri(local,
      'http://127.0.0.1:6080/novnc').host,'127.0.0.1');
  });

  test('rejects executable and credential-bearing screen URLs',(){
    final base=Uri.parse('https://kaka.example');
    expect(()=>resolveComputerScreenUri(base,'javascript:alert(1)'),
      throwsA(isA<KakaApiException>()));
    expect(()=>resolveComputerScreenUri(base,'https://u:p@evil.example/x'),
      throwsA(isA<KakaApiException>()));
  });
}
