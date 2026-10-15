import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PRLiftsApp());
}

class PRLiftsApp extends StatelessWidget {
  const PRLiftsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PR Lifts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const BusinessHome(),
    );
  }
}

class BusinessHome extends StatefulWidget {
  const BusinessHome({super.key});

  @override
  State<BusinessHome> createState() => _BusinessHomeState();
}

class _BusinessHomeState extends State<BusinessHome> {
  final List<Map<String, dynamic>> records = [];
  int selectedTab = 0;
  bool loading = true;

  final List<String> types = [
    'Invoice',
    'Estimate',
    'Quotation',
    'Income',
    'Expense',
  ];

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pr_lifts_records');
    if (saved != null) {
      records.addAll(
        List<Map<String, dynamic>>.from(
          (jsonDecode(saved) as List).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        ),
      );
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'pr_lifts_records',
      jsonEncode(records),
    );
  }

  String money(dynamic value) =>
      '₹${(value as num).toStringAsFixed(2)}';

  Future<void> addRecord() async {
    final customer = TextEditingController();
    final description = TextEditingController();
    final amount = TextEditingController();
    final notes = TextEditingController();

    final type = types[selectedTab];
    final isDocument = selectedTab <= 2;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('New $type'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: customer,
                decoration: const InputDecoration(
                  labelText: 'Customer / Description',
                ),
              ),
              if (isDocument)
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Item / Service',
                  ),
                ),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (INR)',
                  prefixText: '₹ ',
                ),
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(amount.text.trim());
              if (customer.text.trim().isEmpty ||
                  value == null ||
                  value < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a customer/description and valid amount.',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, {
                'customer': customer.text.trim(),
                'description': description.text.trim(),
                'amount': value.toString(),
                'notes': notes.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final number = records.length + 1;
    records.insert(0, {
      'type': type,
      'number': '$type-${number.toString().padLeft(4, '0')}',
      'customer': result['customer'],
      'description': result['description'],
      'amount': double.parse(result['amount']!),
      'notes': result['notes'],
      'date': DateTime.now().toIso8601String(),
    });

    await saveRecords();
    if (mounted) setState(() {});
  }

Future<void> editRecord(Map<String, dynamic> record) async {
  final customer = TextEditingController(
    text: record['customer']?.toString() ?? '',
  );
  final description = TextEditingController(
    text: record['description']?.toString() ?? '',
  );
  final amount = TextEditingController(
    text: record['amount']?.toString() ?? '',
  );
  final notes = TextEditingController(
    text: record['notes']?.toString() ?? '',
  );

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Edit Record'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: customer,
              decoration: const InputDecoration(
                labelText: 'Customer / Description',
              ),
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(
                labelText: 'Item / Service',
              ),
            ),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (INR)',
              ),
            ),
            TextField(
              controller: notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = double.tryParse(amount.text.trim());
            if (customer.text.trim().isEmpty ||
                value == null ||
                !value.isFinite ||
                value < 0) {
              return;
            }
            Navigator.pop(dialogContext, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (result == true && mounted) {
    setState(() {
      record['customer'] = customer.text.trim();
      record['description'] = description.text.trim();
      record['amount'] = double.parse(amount.text.trim());
      record['notes'] = notes.text.trim();
    });
    await saveRecords();
  }

  customer.dispose();
  description.dispose();
  amount.dispose();
  notes.dispose();
}

  @override
  Widget build(BuildContext context) {
    final visible = records
        .where((r) => r['type'] == types[selectedTab])
        .toList();

    final total = visible.fold<double>(
      0,
      (sum, r) => sum + (r['amount'] as num).toDouble(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PR Lifts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: Text('Total ${types[selectedTab]}'),
                    subtitle: const Text('Saved on this device'),
                    trailing: Text(
                      money(total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(types.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text(types[i]),
                          selected: selectedTab == i,
                          onSelected: (_) {
                            setState(() => selectedTab = i);
                          },
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text('No ${types[selectedTab]} records yet.'),
                        )
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final r = visible[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              child: ListTile(
                                onTap: () => showModalBottomSheet<void>(
  context: context,
  builder: (sheetContext) => SafeArea(
    child: Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Edit'),
          
onTap: () {
  Navigator.pop(sheetContext);
  editRecord(r);
},

        ListTile(
          leading: const Icon(Icons.cancel_outlined),
          title: const Text('Cancel'),
          onTap: () => Navigator.pop(sheetContext),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Delete'),
          onTap: () => Navigator.pop(sheetContext),
        ),
      ],
    ),
  ),
),
                                leading: const Icon(Icons.description),
                                title: Text(r['customer'] as String),
                                subtitle: Text(
                                  '${r['number']}\n'
                                  '${r['date'].toString().substring(0, 10)}'
                                  '${(r['description'] as String).isNotEmpty ? '\n${r['description']}' : ''}',
                                ),
                                isThreeLine:
                                    (r['description'] as String).isNotEmpty,
                                trailing: Text(
                                  money(r['amount']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : addRecord,
        icon: const Icon(Icons.add),
        label: Text('New ${types[selectedTab]}'),
      ),
    );
  }
}
