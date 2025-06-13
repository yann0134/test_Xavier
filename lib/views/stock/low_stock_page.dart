import 'package:flutter/material.dart';
import '../../services/database_tools.dart';

class LowStockPage extends StatefulWidget {
  const LowStockPage({Key? key}) : super(key: key);

  @override
  State<LowStockPage> createState() => _LowStockPageState();
}

class _LowStockPageState extends State<LowStockPage> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String _sort = 'urgence';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await DatabaseTools.getStockBas();
    setState(() {
      _products = data;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _sortedProducts {
    final list = [..._products];
    if (_sort == 'urgence') {
      list.sort((a, b) => (a['stock'] as int).compareTo(b['stock'] as int));
    } else if (_sort == 'categorie') {
      list.sort((a, b) =>
          (a['categorie_nom'] ?? '').compareTo(b['categorie_nom'] ?? ''));
    }
    return list;
  }

  String _priority(int stock, int seuil) {
    if (stock <= 0) return 'Urgence haute : vente rapide';
    if (stock <= seuil) return 'Surveillance : stock bas mais ventes lentes';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits en Stock Critique'),
        actions: [
          DropdownButton<String>(
            value: _sort,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'urgence', child: Text('Urgence')),
              DropdownMenuItem(value: 'categorie', child: Text('Catégorie')),
            ],
            onChanged: (v) => setState(() => _sort = v ?? 'urgence'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sortedProducts.length,
              itemBuilder: (context, index) {
                final p = _sortedProducts[index];
                final stock = p['stock'] as int? ?? 0;
                final seuil = p['seuilAlerte'] as int? ?? 0;
                final prio = _priority(stock, seuil);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child:
                          const Icon(Icons.inventory_2, color: Colors.orange),
                    ),
                    title: Text(p['nom'] as String? ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock restant: $stock'),
                        Text('Seuil minimum: $seuil'),
                        if (prio.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              prio,
                              style: TextStyle(
                                color: prio.startsWith('Urgence')
                                    ? Colors.red
                                    : Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {},
                          child: const Text('Demander Réassort'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.notifications),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
