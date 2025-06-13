import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Génération de Rapport IA'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGenerationParams(),
            const SizedBox(height: 24),
            _buildAdvancedParams(),
            const SizedBox(height: 24),
            _buildGenerateButton(),
            const SizedBox(height: 24),
            if (_progress.isNotEmpty) Text(_progress),
            const SizedBox(height: 24),
            _buildHistory(),
            const SizedBox(height: 24),
            if (_aiSummary != null) _buildAISummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerationParams() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paramètres de génération',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButton<String>(
            value: _period,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _period = v;
              });
              if (v == 'custom') {
                _pickDateRange();
              }
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
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_start.toString().split(' ')[0]} - ${_end.toString().split(' ')[0]}',
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Contenu:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          ..._content.keys.map((k) {
            return CheckboxListTile(
              value: _content[k],
              title: Text(k),
              onChanged: (v) {
                setState(() {
                  _content[k] = v ?? false;
                });
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAdvancedParams() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paramètres avancés IA',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Générer une synthèse IA des résultats'),
            value: _summary,
            onChanged: (v) {
              setState(() {
                _summary = v;
              });
            },
          ),
          const SizedBox(height: 8),
          const Text('Niveau de détail'),
          RadioListTile<String>(
            value: 'Résumé',
            groupValue: _detail,
            title: const Text('Résumé'),
            onChanged: (v) {
              setState(() => _detail = v!);
            },
          ),
          RadioListTile<String>(
            value: 'Détaillé',
            groupValue: _detail,
            title: const Text('Détaillé'),
            onChanged: (v) {
              setState(() => _detail = v!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _generating ? null : _generate,
        icon: _generating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(_generating ? 'Génération...' : 'Générer le rapport'),
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historique des rapports',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ..._history.map((e) => ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(e),
            )),
      ],
    );
  }

  Widget _buildAISummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Résumé IA',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_aiSummary ?? ''),
        ],
      ),
    );
  }
}
