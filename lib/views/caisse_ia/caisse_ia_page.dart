import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:scoped_model/scoped_model.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/llm_agent_model.dart';

class MessageContent {
  final String type; // 'text', 'image', 'chart', 'pdf', 'table'
  final String content;
  final Map<String, dynamic>? metadata;
  final List<List<String>>? tableData;
  final List<String>? headers;

  MessageContent({
    required this.type,
    required this.content,
    this.metadata,
    this.tableData,
    this.headers,
  });
}

class CaisseIAPage extends StatefulWidget {
  const CaisseIAPage({super.key});

  @override
  _CaisseIAPageState createState() => _CaisseIAPageState();
}

class _CaisseIAPageState extends State<CaisseIAPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LLMAgentModel _model = LLMAgentModel();

  @override
  Widget build(BuildContext context) {
    return ScopedModel<LLMAgentModel>(
      model: _model,
      child: Scaffold(
        body: Container(
          color: Colors.grey[100],
          child: Column(
            children: [
              // En-tête
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                color: Colors.white,
                child: Row(
                  children: [
                    Icon(Icons.smart_toy, color: Colors.blue),
                    SizedBox(width: 12),
                    Text(
                      'Assistant IA – CaissePro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(left: 12),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Connecté à Ollama',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Zone de chat modifiée
              Expanded(
                child: ScopedModelDescendant<LLMAgentModel>(
                  builder: (context, child, model) {
                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(24),
                      itemCount: model.messages.length,
                      itemBuilder: (context, index) {
                        final message = model.messages[index];
                        final contents =
                            jsonDecode(message['contents'] as String);
                        final messageContents = (contents as List)
                            .map((content) => MessageContent(
                                  type: content['type'] as String,
                                  content: content['content'] as String,
                                  metadata: content['metadata']
                                      as Map<String, dynamic>?,
                                  tableData:
                                      (content['tableData'] as List?)
                                          ?.map<List<String>>(
                                              (row) => (row as List)
                                                  .map((e) => e.toString())
                                                  .toList())
                                          .toList(),
                                  headers: (content['headers'] as List?)
                                      ?.map((e) => e.toString())
                                      .toList(),
                                ))
                            .toList();

                        return _buildMessageBubble(
                          messageContents,
                          isUser: message['isUser'],
                        );
                      },
                    );
                  },
                ),
              ),
              // Indicateur de frappe
              ScopedModelDescendant<LLMAgentModel>(
                builder: (context, child, model) {
                  return model.isTyping
                      ? Container(
                          padding: EdgeInsets.all(16),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              SizedBox(width: 24),
                              Container(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'CaisseIA réfléchit...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SizedBox();
                },
              ),
              // Zone de saisie
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _messageController,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText:
                                'Posez moi une question ou demandez une analyse...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    IconButton.filled(
                      onPressed: _sendMessage,
                      icon: Icon(Icons.send),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(MessageContent content) {
    switch (content.type) {
      case 'image':
        return GestureDetector(
          onTap: () => _showImageDialog(context, content.content),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: 200,
              maxWidth: 300,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                content.content,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                fit: BoxFit.contain,
              ),
            ),
          ),
        );

      case 'chart':
        return Container(
          constraints: BoxConstraints(
            maxHeight: 300,
            maxWidth: 400,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: // Intégrez ici votre widget de graphique
              Image.network(content.content), // Temporaire pour l'exemple
        );

      case 'table':
        final headers = content.headers ?? [];
        final rows = content.tableData ?? [];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns:
                headers.map((h) => DataColumn(label: Text(h))).toList(),
            rows: rows
                .map((r) => DataRow(
                      cells: r
                          .map((c) => DataCell(Text(c.toString())))
                          .toList(),
                    ))
                .toList(),
          ),
        );

      case 'pdf':
        return GestureDetector(
          onTap: () => _openPdf(content.content),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    content.metadata?['name'] ?? 'Document PDF',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                Icon(Icons.download, color: Colors.grey),
              ],
            ),
          ),
        );

      default: // 'text'
        return Text(
          content.content,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 15,
          ),
        );
    }
  }

  Widget _buildMessageBubble(List<MessageContent> contents,
      {required bool isUser}) {
    return Container(
      margin: EdgeInsets.only(
        left: isUser ? 80 : 0,
        right: isUser ? 0 : 80,
        bottom: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 40,
              height: 40,
              margin: EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.smart_toy, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isUser ? Colors.blue : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: contents.map((content) {
                  return Container(
                    padding: EdgeInsets.all(12),
                    child: _buildMessageContent(content),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            PhotoView(
              imageProvider: NetworkImage(imageUrl),
              backgroundDecoration: BoxDecoration(color: Colors.transparent),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPdf(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    _model.sendMessage(message);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
