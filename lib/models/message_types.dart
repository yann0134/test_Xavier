enum MessageType { text, table, chart, image, pdf }

class MessageData {
  final MessageType type;
  final String content;
  final Map<String, dynamic>? metadata;
  final List<List<String>>? tableData;
  final List<String>? headers;

  MessageData({
    required this.type,
    required this.content,
    this.metadata,
    this.tableData,
    this.headers,
  });

  factory MessageData.text(String content) {
    return MessageData(type: MessageType.text, content: content);
  }

  factory MessageData.table(List<List<String>> data, List<String> headers) {
    return MessageData(
      type: MessageType.table,
      content: '',
      tableData: data,
      headers: headers,
    );
  }

  factory MessageData.pdf(String filePath, {Map<String, dynamic>? metadata}) {
    return MessageData(
      type: MessageType.pdf,
      content: filePath,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'content': content,
      'metadata': metadata,
      'tableData': tableData,
      'headers': headers,
    };
  }

  static MessageData fromJson(Map<String, dynamic> json) {
    return MessageData(
      type: MessageType.values.firstWhere(
          (t) => t.toString() == 'MessageType.${json['type']}',
          orElse: () => MessageType.text),
      content: json['content'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      tableData: json['tableData'] as List<List<String>>?,
      headers: json['headers'] as List<String>?,
    );
  }
}
