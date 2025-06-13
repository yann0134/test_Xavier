import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';

class RapportIAPage extends StatefulWidget {
  const RapportIAPage({Key? key}) : super(key: key);

  @override
  State<RapportIAPage> createState() => _RapportIAPageState();
}

class _RapportIAPageState extends State<RapportIAPage> {
  String _period = 'today';
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  final Map<String, bool> _content = {
    'Ventes globales': true,
    'Détails vendeurs': false,
    'Détails produits': false,
    'Anomalies détectées': false,
    'Objectifs journaliers': false,
  };
  bool _summary = true;
  String _detail = 'Résumé';
  bool _generating = false;
  String _progress = '';
  String? _aiSummary;
  final List<String> _history = [];
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _start = picked.start;
        _end = picked.end;
      });
    }
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _progress = 'Traitement des ventes...';
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _generating = false;
      _progress = 'Rapport généré';
      _aiSummary =
          'Sur la période du ${_start.toString().split(' ')[0]} au ${_end.toString().split(' ')[0]}, le chiffre d\'affaires total s\'élève à 0 FCFA.';
      _history.insert(0, 'Rapport du ${DateTime.now()}');
    });
  }

  Future<void> _downloadReport(String date) async {
    try {
      setState(() {
        _progress = 'Génération du PDF...';
        _generating = true;
      });

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Rapport d\'analyse IA',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Généré le $date'),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, text: 'Période analysée'),
            pw.Text(
                '${_start.toString().split(' ')[0]} au ${_end.toString().split(' ')[0]}'),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, text: 'Analyse'),
            pw.Text(_aiSummary ?? 'Aucune analyse disponible'),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, text: 'Éléments analysés'),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _content.entries
                  .where((e) => e.value)
                  .map((e) => pw.Padding(
                        padding: pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text('• ${e.key}'),
                      ))
                  .toList(),
            ),
          ],
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/rapport_ia_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);

      setState(() {
        _progress = 'Rapport téléchargé';
        _generating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rapport téléchargé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _progress = 'Erreur lors du téléchargement';
        _generating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la génération du rapport'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Assistant Rapport IA',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_generating)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _progress,
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.help_outline, color: Colors.grey[600]),
            onPressed: () {
              // TODO: Afficher l'aide
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Panneau latéral des paramètres
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Période d\'analyse'),
                _buildPeriodSelector(),
                _buildSectionTitle('Contenu du rapport'),
                _buildContentSelector(),
                _buildSectionTitle('Configuration IA'),
                _buildAIConfig(),
                Spacer(),
                _buildGenerateButton(),
              ],
            ),
          ),
          // Zone principale de contenu
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_aiSummary != null) ...[
                      _buildReportHeader(),
                      SizedBox(height: 24),
                      _buildAISummaryCard(),
                    ],
                    if (_history.isNotEmpty) ...[
                      SizedBox(height: 32),
                      _buildHistorySection(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _period,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _period = v);
              if (v == 'custom') _pickDateRange();
            },
            items: const [
              DropdownMenuItem(value: 'today', child: Text('Aujourd\'hui')),
              DropdownMenuItem(value: 'week', child: Text('Cette semaine')),
              DropdownMenuItem(value: 'month', child: Text('Ce mois-ci')),
              DropdownMenuItem(value: 'custom', child: Text('Personnalisé')),
            ],
          ),
          if (_period == 'custom')
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '${_start.toString().split(' ')[0]} - ${_end.toString().split(' ')[0]}',
                style: TextStyle(color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContentSelector() {
    return Column(
      children: _content.keys.map((k) {
        return CheckboxListTile(
          value: _content[k],
          title: Text(k),
          dense: true,
          onChanged: (v) => setState(() => _content[k] = v ?? false),
        );
      }).toList(),
    );
  }

  Widget _buildAIConfig() {
    return Column(
      children: [
        SwitchListTile(
          title: Text('Synthèse IA'),
          subtitle: Text('Générer une analyse détaillée'),
          value: _summary,
          onChanged: (v) => setState(() => _summary = v),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Niveau de détail', style: TextStyle(fontSize: 14)),
              Row(
                children: [
                  Radio(
                    value: 'Résumé',
                    groupValue: _detail,
                    onChanged: (v) => setState(() => _detail = v as String),
                  ),
                  Text('Résumé'),
                  Radio(
                    value: 'Détaillé',
                    groupValue: _detail,
                    onChanged: (v) => setState(() => _detail = v as String),
                  ),
                  Text('Détaillé'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      padding: EdgeInsets.all(16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _generating ? null : _generate,
        icon: _generating
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(Icons.auto_awesome),
        label: Text(_generating ? 'Génération...' : 'Générer le rapport'),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildReportHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rapport d\'analyse',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Généré le ${DateTime.now().toString().split('.')[0]}',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAISummaryCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blue),
              SizedBox(width: 12),
              Text(
                'Analyse IA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            _aiSummary ?? '',
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historique des rapports',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          ..._history.map((date) => ListTile(
                leading: Icon(Icons.description, color: Colors.blue),
                title: Text(date),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.download, color: Colors.grey[600]),
                      onPressed: () => _downloadReport(date),
                      tooltip: 'Télécharger le rapport',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.grey[600]),
                      onPressed: () {
                        setState(() {
                          _history.remove(date);
                        });
                      },
                      tooltip: 'Supprimer de l\'historique',
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
