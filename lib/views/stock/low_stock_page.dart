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
  String _filterCategory = 'all';
  Set<String> _categories = {'all'};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await DatabaseTools.getStockBas();
    final categories = data
        .map((p) => p['categorie_nom'] as String? ?? 'Non catégorisé')
        .toSet();

    setState(() {
      _products = data;
      _categories = {'all', ...categories};
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredAndSortedProducts {
    final list = _filterCategory == 'all'
        ? [..._products]
        : _products
            .where((p) => p['categorie_nom'] == _filterCategory)
            .toList();

    if (_sort == 'urgence') {
      list.sort((a, b) => (a['stock'] as int).compareTo(b['stock'] as int));
    } else if (_sort == 'categorie') {
      list.sort((a, b) =>
          (a['categorie_nom'] ?? '').compareTo(b['categorie_nom'] ?? ''));
    }
    return list;
  }

  Widget _buildHeader() {
    final urgentCount = _products.where((p) => (p['stock'] as int) <= 0).length;
    final warningCount = _products.length - urgentCount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            'Aperçu du stock',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 24),
          Row(
            children: [
              _buildStatCard(
                'Rupture de stock',
                urgentCount.toString(),
                Icons.error_outline,
                Colors.red,
              ),
              SizedBox(width: 16),
              _buildStatCard(
                'Stock faible',
                warningCount.toString(),
                Icons.warning_amber,
                Colors.orange,
              ),
              SizedBox(width: 16),
              _buildStatCard(
                'Total produits',
                _products.length.toString(),
                Icons.inventory_2,
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16),
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
      child: Row(
        children: [
          Icon(Icons.filter_list, color: Colors.grey[600]),
          SizedBox(width: 12),
          DropdownButton<String>(
            value: _filterCategory,
            hint: Text('Catégorie'),
            underline: SizedBox(),
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category == 'all' ? 'Toutes catégories' : category),
              );
            }).toList(),
            onChanged: (value) => setState(() => _filterCategory = value!),
          ),
          SizedBox(width: 24),
          Icon(Icons.sort, color: Colors.grey[600]),
          SizedBox(width: 12),
          DropdownButton<String>(
            value: _sort,
            underline: SizedBox(),
            items: const [
              DropdownMenuItem(value: 'urgence', child: Text('Par urgence')),
              DropdownMenuItem(
                  value: 'categorie', child: Text('Par catégorie')),
            ],
            onChanged: (v) => setState(() => _sort = v ?? 'urgence'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    final products = _filteredAndSortedProducts;
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        final stock = p['stock'] as int? ?? 0;
        final seuil = p['seuilAlerte'] as int? ?? 0;
        final isUrgent = stock <= 0;

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUrgent
                  ? Colors.red.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUrgent
                    ? Colors.red.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_2,
                color: isUrgent ? Colors.red : Colors.orange,
              ),
            ),
            title: Row(
              children: [
                Text(
                  p['nom'] as String? ?? '',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                if (isUrgent) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'URGENT',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Row(
                  children: [
                    _buildProgressIndicator(stock, seuil),
                    SizedBox(width: 16),
                    Text(
                      'Stock: $stock / Seuil: $seuil',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text('Réassort'),
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isUrgent ? Colors.red : Colors.blue,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator(int stock, int seuil) {
    final progress = stock / (seuil * 2);
    final color = stock <= 0
        ? Colors.red
        : stock <= seuil
            ? Colors.orange
            : Colors.green;

    return Container(
      width: 100,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: color.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Gestion du Stock',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: 24),
                  _buildFilters(),
                  SizedBox(height: 24),
                  _buildProductList(),
                ],
              ),
            ),
    );
  }
}
