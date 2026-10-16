import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const PRBusinessApp());

const String recordsKey = 'pr_business_records';
const String stockKey = 'pr_business_stock_v1';

class PRBusinessApp extends StatelessWidget {
  const PRBusinessApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PR Business',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> records = [];
  List<Map<String, dynamic>> stock = [];
  bool loading = true;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final r = jsonDecode(prefs.getString(recordsKey) ?? '[]') as List;
      records = r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      records = [];
    }
    try {
      final s = jsonDecode(prefs.getString(stockKey) ?? '[]') as List;
      stock = s.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      stock = [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(recordsKey, jsonEncode(records));
    await prefs.setString(stockKey, jsonEncode(stock));
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> addRecord(String type) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => RecordForm(type: type, stock: stock)),
    );
    if (result == null) return;

    final items = (result['items'] as List?) ?? [];
    if (type == 'Invoice') {
      for (final raw in items) {
        final item = Map<String, dynamic>.from(raw as Map);
        final code = (item['code'] ?? '').toString();
        final qty = _num(item['qty']);
        final index = stock.indexWhere((s) => (s['code'] ?? '').toString() == code);
        if (index >= 0) {
          final available = _num(stock[index]['qty']);
          if (available < qty) {
            message('സ്റ്റോക്കിൽ മതിയായ അളവില്ല: ${item['name']}');
            return;
          }
        }
      }
      for (final raw in items) {
        final item = Map<String, dynamic>.from(raw as Map);
        final index = stock.indexWhere((s) => (s['code'] ?? '').toString() == (item['code'] ?? '').toString());
        if (index >= 0) stock[index]['qty'] = _num(stock[index]['qty']) - _num(item['qty']);
      }
    }
    result['id'] = _nextId(type);
    result['type'] = type;
    result['date'] = DateTime.now().toIso8601String();
    records.insert(0, result);
    await saveData();
    if (mounted) setState(() {});
    message('$type സേവ് ചെയ്തു');
  }

  double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _nextId(String type) {
    final prefix = {'Invoice': 'INV', 'Estimate': 'EST', 'Quotation': 'QUO', 'Income': 'INC', 'Expense': 'EXP'}[type] ?? 'REC';
    final count = records.where((r) => r['type'] == type).length + 1;
    return '$prefix-${count.toString().padLeft(4, '0')}';
  }

  Future<void> addStock() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const StockForm()),
    );
    if (result == null) return;
    final code = (result['code'] ?? '').toString();
    final index = stock.indexWhere((s) => (s['code'] ?? '').toString() == code);
    if (index >= 0) {
      stock[index]['qty'] = _num(stock[index]['qty']) + _num(result['qty']);
      stock[index]['name'] = result['name'];
      stock[index]['purchase'] = result['purchase'];
      stock[index]['selling'] = result['selling'];
    } else {
      stock.add(result);
    }
    await saveData();
    if (mounted) setState(() {});
    message('സ്റ്റോക്ക് സേവ് ചെയ്തു');
  }

  Future<void> exportBackup() async {
    try {
      final data = <String, dynamic>{
        'app': 'PR Business',
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'records': records,
        'stock': stock,
      };
      final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'PR Business ബാക്കപ്പ് സൂക്ഷിക്കുക',
        fileName: 'PR_Business_Backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (path != null) message('ബാക്കപ്പ് ഫയൽ തയ്യാറാക്കി');
    } catch (e) {
      message('ബാക്കപ്പ് പരാജയപ്പെട്ടു: $e');
    }
  }

  Future<void> importBackup() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (picked == null) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null) throw Exception('ഫയൽ വായിക്കാൻ കഴിഞ്ഞില്ല');
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['app'] != 'PR Business' || decoded['records'] is! List || decoded['stock'] is! List) {
        throw const FormatException('ശരിയായ PR Business ബാക്കപ്പ് ഫയലല്ല');
      }
      final newRecords = (decoded['records'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final newStock = (decoded['stock'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ബാക്കപ്പ് പുനഃസ്ഥാപിക്കണോ?'),
          content: const Text('ഇപ്പോൾ ഉള്ള രേഖകളും സ്റ്റോക്കും ബാക്കപ്പിലെ വിവരങ്ങൾ ഉപയോഗിച്ച് മാറ്റിസ്ഥാപിക്കും. ആദ്യം നിലവിലെ ഡാറ്റയുടെ ബാക്കപ്പ് എടുത്തിട്ടുണ്ടെന്ന് ഉറപ്പാക്കുക.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('റദ്ദാക്കുക')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('പുനഃസ്ഥാപിക്കുക')),
          ],
        ),
      );
      if (ok != true) return;
      final prefs = await SharedPreferences.getInstance();
      final oldRecords = prefs.getString(recordsKey);
      final oldStock = prefs.getString(stockKey);
      try {
        await prefs.setString(recordsKey, jsonEncode(newRecords));
        await prefs.setString(stockKey, jsonEncode(newStock));
        if (!mounted) return;
        setState(() {
          records = newRecords;
          stock = newStock;
        });
        message('ബാക്കപ്പ് പുനഃസ്ഥാപിച്ചു');
      } catch (_) {
        if (oldRecords != null) await prefs.setString(recordsKey, oldRecords);
        if (oldStock != null) await prefs.setString(stockKey, oldStock);
        rethrow;
      }
    } catch (e) {
      message('പുനഃസ്ഥാപിക്കൽ പരാജയപ്പെട്ടു: $e');
    }
  }

  double get totalIncome => records.where((r) => r['type'] == 'Income').fold(0, (a, r) => a + _num(r['total']));
  double get totalExpense => records.where((r) => r['type'] == 'Expense').fold(0, (a, r) => a + _num(r['total']));
  double get totalSales => records.where((r) => r['type'] == 'Invoice').fold(0, (a, r) => a + _num(r['total']));
  String money(dynamic value) => '₹${_num(value).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = <Widget>[
      _dashboard(),
      _recordsPage(),
      _stockPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('PR BUSINESS'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.backup_outlined),
            tooltip: 'ബാക്കപ്പ് / പുനഃസ്ഥാപിക്കൽ',
            onSelected: (v) => v == 'backup' ? exportBackup() : importBackup(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'backup', child: Text('ബാക്കപ്പ് എടുക്കുക')),
              PopupMenuItem(value: 'restore', child: Text('ബാക്കപ്പിൽ നിന്ന് പുനഃസ്ഥാപിക്കുക')),
            ],
          ),
        ],
      ),
      body: pages[tab],
      floatingActionButton: tab == 2
          ? FloatingActionButton.extended(onPressed: addStock, icon: const Icon(Icons.add), label: const Text('സ്റ്റോക്ക് ചേർക്കുക'))
          : tab == 1
              ? FloatingActionButton(onPressed: () => _showAddMenu(), child: const Icon(Icons.add))
              : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'ഹോം'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'രേഖകൾ'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'സ്റ്റോക്ക്'),
        ],
      ),
    );
  }

  Widget _dashboard() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('PR Business', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text('ഇൻവോയ്സ്, വരുമാനം, ചെലവ്, സ്റ്റോക്ക് എന്നിവ കൈകാര്യം ചെയ്യുക.'),
          const SizedBox(height: 18),
          _summaryCard('ഇൻവോയ്സ് വിൽപ്പന', money(totalSales), Icons.receipt_long),
          _summaryCard('മറ്റ് വരുമാനം', money(totalIncome), Icons.trending_up),
          _summaryCard('ചെലവ്', money(totalExpense), Icons.trending_down),
          _summaryCard('സ്റ്റോക്ക് ഇനങ്ങൾ', '${stock.length}', Icons.inventory_2),
          const SizedBox(height: 12),
          const Text('പുതിയ രേഖകൾ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...records.take(5).map(_recordTile),
        ],
      );

  Widget _summaryCard(String title, String value, IconData icon) => Card(
        child: ListTile(leading: Icon(icon, size: 30), title: Text(title), trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
      );

  Widget _recordsPage() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final type in ['Invoice', 'Estimate', 'Quotation', 'Income', 'Expense'])
              OutlinedButton.icon(onPressed: () => addRecord(type), icon: const Icon(Icons.add), label: Text(type)),
          ]),
          const SizedBox(height: 12),
          if (records.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('രേഖകൾ ഒന്നും ചേർത്തിട്ടില്ല.'))),
          ...records.map(_recordTile),
        ],
      );

  Widget _recordTile(Map<String, dynamic> r) => Card(
        child: ListTile(
          leading: Icon(r['type'] == 'Expense' ? Icons.money_off : r['type'] == 'Income' ? Icons.attach_money : Icons.receipt),
          title: Text('${r['id'] ?? ''} • ${r['customer'] ?? r['title'] ?? r['type'] ?? ''}'),
          subtitle: Text('${r['type'] ?? ''} • ${(r['date'] ?? '').toString().split('T').first}'),
          trailing: Text(money(r['total'])),
          onTap: () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
            title: Text('${r['id'] ?? ''}'),
            content: SingleChildScrollView(child: Text(const JsonEncoder.withIndent('  ').convert(r))),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('അടയ്ക്കുക'))],
          )),
        ),
      );

  Widget _stockPage() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (stock.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('സ്റ്റോക്ക് ഇനങ്ങൾ ചേർത്തിട്ടില്ല.'))),
          ...stock.map((s) => Card(child: ListTile(
            leading: const Icon(Icons.inventory_2),
            title: Text('${s['name'] ?? ''} (${s['code'] ?? ''})'),
            subtitle: Text('വാങ്ങൽ: ${money(s['purchase'])} • വിൽപ്പന: ${money(s['selling'])}'),
            trailing: Text('${_num(s['qty']).toStringAsFixed(0)} ${s['unit'] ?? 'Nos'}'),
          ))),
        ],
      );

  Future<void> _showAddMenu() async {
    final type = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final t in ['Invoice', 'Estimate', 'Quotation', 'Income', 'Expense'])
        ListTile(leading: const Icon(Icons.add_circle_outline), title: Text(t), onTap: () => Navigator.pop(ctx, t)),
    ])));
    if (type != null) addRecord(type);
  }
}

class RecordForm extends StatefulWidget {
  final String type;
  final List<Map<String, dynamic>> stock;
  const RecordForm({super.key, required this.type, required this.stock});
  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  final formKey = GlobalKey<FormState>();
  final customer = TextEditingController();
  final notes = TextEditingController();
  final amount = TextEditingController();
  final List<Map<String, dynamic>> items = [];
  String? selectedCode;
  final qtyController = TextEditingController(text: '1');

  double n(dynamic x) => x is num ? x.toDouble() : double.tryParse('$x') ?? 0;
  double get total => widget.type == 'Invoice' || widget.type == 'Estimate' || widget.type == 'Quotation'
      ? items.fold(0, (a, i) => a + n(i['qty']) * n(i['price']))
      : n(amount.text);

  @override
  void dispose() {
    customer.dispose(); notes.dispose(); amount.dispose(); qtyController.dispose(); super.dispose();
  }

  void addItem() {
    Map<String, dynamic>? item;
    for (final candidate in widget.stock) {
      if (candidate['code'].toString() == selectedCode) {
        item = candidate;
        break;
      }
    }
    if (item == null) return;
    final qty = n(qtyController.text);
    if (qty <= 0) return;
    setState(() => items.add({'code': item['code'], 'name': item['name'], 'qty': qty, 'price': n(item['selling'])}));
    qtyController.text = '1';
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = ['Invoice', 'Estimate', 'Quotation'].contains(widget.type);
    return Scaffold(
      appBar: AppBar(title: Text('${widget.type} ചേർക്കുക')),
      body: Form(
        key: formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: customer, decoration: InputDecoration(labelText: widget.type == 'Income' || widget.type == 'Expense' ? 'വിവരണം' : 'ഉപഭോക്താവിന്റെ പേര്'), validator: (v) => (v == null || v.trim().isEmpty) ? 'ഈ ഭാഗം പൂരിപ്പിക്കുക' : null),
          if (hasItems) ...[
            const SizedBox(height: 12),
            if (widget.stock.isEmpty) const Text('ഇനങ്ങൾ ചേർക്കുന്നതിന് മുമ്പ് സ്റ്റോക്ക് പേജിൽ ഇനം ചേർക്കുക.'),
            DropdownButtonFormField<String>(
              value: selectedCode,
              decoration: const InputDecoration(labelText: 'സ്റ്റോക്ക് ഇനം'),
              items: widget.stock.map((s) => DropdownMenuItem(value: s['code'].toString(), child: Text('${s['name']} (${s['code']})'))).toList(),
              onChanged: (v) => setState(() => selectedCode = v),
            ),
            TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'അളവ്')),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: addItem, icon: const Icon(Icons.add), label: const Text('ഇനം ചേർക്കുക'))),
            ...items.asMap().entries.map((entry) => ListTile(
              title: Text('${entry.value['name']} × ${entry.value['qty']}'),
              subtitle: Text('വില: ₹${n(entry.value['price']).toStringAsFixed(2)}'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => items.removeAt(entry.key))),
            )),
          ] else ...[
            TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'തുക (₹)'), validator: (v) => n(v) <= 0 ? 'ശരിയായ തുക നൽകുക' : null, onChanged: (_) => setState(() {})),
          ],
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'കുറിപ്പുകൾ (ഐച്ഛികം)')),
          const SizedBox(height: 18),
          Card(child: ListTile(title: const Text('ആകെ തുക'), trailing: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              if (hasItems && items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('കുറഞ്ഞത് ഒരു ഇനം ചേർക്കുക')));
                return;
              }
              Navigator.pop(context, {
                'customer': customer.text.trim(),
                'title': customer.text.trim(),
                'notes': notes.text.trim(),
                'items': items,
                'total': total,
              });
            },
            icon: const Icon(Icons.save), label: const Text('സേവ് ചെയ്യുക'),
          ),
        ]),
      ),
    );
  }
}

class StockForm extends StatefulWidget {
  const StockForm({super.key});
  @override
  State<StockForm> createState() => _StockFormState();
}

class _StockFormState extends State<StockForm> {
  final keyForm = GlobalKey<FormState>();
  final code = TextEditingController();
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  final purchase = TextEditingController(text: '0');
  final selling = TextEditingController(text: '0');
  final unit = TextEditingController(text: 'Nos');
  double n(String x) => double.tryParse(x) ?? 0;

  @override
  void dispose() { code.dispose(); name.dispose(); qty.dispose(); purchase.dispose(); selling.dispose(); unit.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('സ്റ്റോക്ക് ഇനം ചേർക്കുക')),
        body: Form(key: keyForm, child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: code, decoration: const InputDecoration(labelText: 'ഇനം കോഡ്'), validator: (v) => v == null || v.trim().isEmpty ? 'കോഡ് നൽകുക' : null),
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'ഇനത്തിന്റെ പേര്'), validator: (v) => v == null || v.trim().isEmpty ? 'പേര് നൽകുക' : null),
          TextFormField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ആരംഭ സ്റ്റോക്ക് അളവ്')),
          TextFormField(controller: unit, decoration: const InputDecoration(labelText: 'യൂണിറ്റ് (Nos, Kg...)')),
          TextFormField(controller: purchase, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'വാങ്ങൽ വില (₹)')),
          TextFormField(controller: selling, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'വിൽപ്പന വില (₹)')),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: () {
            if (!keyForm.currentState!.validate()) return;
            Navigator.pop(context, {'code': code.text.trim(), 'name': name.text.trim(), 'qty': n(qty.text), 'unit': unit.text.trim().isEmpty ? 'Nos' : unit.text.trim(), 'purchase': n(purchase.text), 'selling': n(selling.text)});
          }, icon: const Icon(Icons.save), label: const Text('സ്റ്റോക്ക് സേവ് ചെയ്യുക')),
        ])),
      );
}
