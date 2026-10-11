// Models mirror the server's public JSON contracts. Unknown blocks are preserved.
class KakaBot {
  final String id;
  final String name;
  final String title;
  final String preview;
  final String color;
  final String status;
  final bool unread;
  final bool pinned;
  final String updatedAt;
  final String? threadId;
  const KakaBot({
    required this.id, required this.name, required this.title,
    required this.preview, required this.color, required this.status,
    required this.unread, required this.pinned, required this.updatedAt,
    this.threadId,
  });
  factory KakaBot.fromJson(Map<String, dynamic> m) => KakaBot(
    id: '${m['id'] ?? ''}', name: '${m['name'] ?? ''}',
    title: '${m['title'] ?? ''}', preview: '${m['preview'] ?? ''}',
    color: '${m['color'] ?? '#181818'}',
    status: '${m['status'] ?? ''}', unread: m['unread'] == true,
    pinned: m['pinned'] == true, updatedAt: '${m['updatedAt'] ?? ''}',
    threadId: m['threadId']?.toString(),
  );
}

class KakaSpace {
  final String id;
  final String name;
  const KakaSpace(this.id, this.name);
  factory KakaSpace.fromJson(Map<String, dynamic> m) =>
      KakaSpace('${m['id'] ?? ''}', '${m['name'] ?? ''}');
}

class KakaGroup {
  final String id, name, preview;
  final bool unread;
  const KakaGroup(this.id, this.name, this.preview, this.unread);
  factory KakaGroup.fromJson(Map<String, dynamic> m) =>
      KakaGroup('${m['id'] ?? ''}', '${m['name'] ?? ''}',
        '${m['preview'] ?? ''}', m['unread'] == true);
}

class KakaMessage {
  final String id, role;
  final String? botId, createdAt, runId;
  final List<Map<String, dynamic>> blocks;
  const KakaMessage({
    required this.id, required this.role, required this.blocks,
    this.botId, this.createdAt, this.runId,
  });
  factory KakaMessage.fromJson(Map<String, dynamic> m) => KakaMessage(
    id: '${m['id'] ?? ''}', role: '${m['role'] ?? 'bot'}',
    botId: m['botId']?.toString(), createdAt: m['createdAt']?.toString(),
    runId: m['runId']?.toString(),
    blocks: (m['blocks'] is List ? m['blocks'] as List : const [])
        .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
  );
  String get text => blocks.where((e) => e['kind'] == 'text')
      .map((e) => '${e['text'] ?? ''}').join('\n');
}

class KakaThread {
  final String threadId;
  final int cursor;
  final int? olderCursor;
  final String? runStatus;
  final List<KakaMessage> messages;
  const KakaThread({
    required this.threadId, required this.cursor, required this.messages,
    this.olderCursor, this.runStatus,
  });
  factory KakaThread.fromJson(Map<String, dynamic> m) => KakaThread(
    threadId: '${m['threadId'] ?? ''}',
    cursor: (m['cursor'] as num?)?.toInt() ?? 0,
    olderCursor: (m['olderCursor'] as num?)?.toInt(),
    runStatus: (m['run'] is Map) ? m['run']['status']?.toString() : null,
    messages: (m['messages'] is List ? m['messages'] as List : const [])
      .whereType<Map>().map((e) => KakaMessage.fromJson(Map<String, dynamic>.from(e))).toList(),
  );
}

class KakaThreadEvent {
  final String type;
  final int? seq;
  final String? id, botId, runId;
  final Map<String, dynamic> payload;
  KakaThreadEvent(Map<String, dynamic> json)
      : type = '${json['type'] ?? ''}',
        seq = (json['seq'] as num?)?.toInt(),
        id = json['id']?.toString(),
        botId = json['botId']?.toString(),
        runId = json['runId']?.toString(),
        payload = json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map) : {};
}
