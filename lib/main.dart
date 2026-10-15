
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const PRBusinessApp());
}

class PRBusinessApp extends StatelessWidget {
  const PRBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PR BUSINESS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const RecordsPage(),
    );
  }
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final List<String> types = [
    'Invoice',
    'Estimate',
    'Quotation',
    'Income',
    'Expense',
  ];

  List<Map<String, dynamic>> records = [];
  int selectedTab = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pr_business_records');

    if (saved != null) {
      try {
        final decoded = jsonDecode(saved) as List;
        records = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {
        records = [];
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'pr_business_records',
      jsonEncode(records),
    );
  }

  String money(dynamic value) {
    final amount = double.tryParse('$value') ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  String nextNumber(String type) {
    final prefix = {
      'Invoice': 'INV',
      'Estimate': 'EST',
      'Quotation': 'QUO',
      'Income': 'INC',
      'Expense': 'EXP',
    }[type]!;

    var highest = 0;

    for (final record in records) {
      if (record['type'] == type) {
        final number = '${record['number']}';
        final parts = number.split('-');

        if (parts.length == 2) {
          final value = int.tryParse(parts[1]) ?? 0;
          if (value > highest) highest = value;
        }
      }
    }

    return '$prefix-${(highest + 1).toString().padLeft(4, '0')}';
  }

  Future<Map<String, dynamic>?> recordDialog({
    Map<String, dynamic>? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final customer = TextEditingController(
      text: '${existing?['customer'] ?? ''}',
    );
    final phone = TextEditingController(
      text: '${existing?['phone'] ?? ''}',
    );
    final description = TextEditingController(
      text: '${existing?['description'] ?? ''}',
    );
    final amount = TextEditingController(
      text: existing == null ? '' : '${existing['amount']}',
    );
    final notes = TextEditingController(
      text: '${existing?['notes'] ?? ''}',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'New ${types[selectedTab]}' : 'Edit Record'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: customer,
                  decoration: const InputDecoration(
                    labelText: 'Customer / Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty
                          ? 'Enter a name'
                          : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Item / Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final value = double.tryParse(v ?? '');
                    if (value == null || value < 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              Navigator.pop(dialogContext, {
                'customer': customer.text.trim(),
                'phone': phone.text.trim(),
                'description': description.text.trim(),
                'amount': double.parse(amount.text.trim()),
                'notes': notes.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    customer.dispose();
    phone.dispose();
    description.dispose();
    amount.dispose();
    notes.dispose();

    return result;
  }

  Future<void> addRecord() async {
    final data = await recordDialog();
    if (data == null) return;

    final type = types[selectedTab];

    setState(() {
      records.insert(0, {
        ...data,
        'type': type,
        'number': nextNumber(type),
        'date': DateTime.now().toIso8601String(),
        'status': 'Active',
      });
    });

    await saveRecords();
  }

  Future<void> editRecord(Map<String, dynamic> record) async {
    final data = await recordDialog(existing: record);
    if (data == null) return;

    setState(() {
      record.addAll(data);
    });

    await saveRecords();
  }

  Future<void> deleteRecord(Map<String, dynamic> record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: const Text('This record will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => records.remove(record));
    await saveRecords();
  }

  Future<Uint8List> makePdf(Map<String, dynamic> record) async {
    final doc = pw.Document();
    final type = '${record['type']}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PR BUSINESS',
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                type.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Text('Number: ${record['number']}'),
              pw.Text(
                'Date: ${record['date'].toString().substring(0, 10)}',
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                'Customer: ${record['customer']}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              if ('${record['phone'] ?? ''}'.isNotEmpty)
                pw.Text('Phone: ${record['phone']}'),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Amount',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${record['description'] ?? ''}',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(money(record['amount'])),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total: ${money(record['amount'])}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if ('${record['notes'] ?? ''}'.isNotEmpty) ...[
                pw.SizedBox(height: 18),
                pw.Text('Notes: ${record['notes']}'),
              ],
              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text('Thank you'),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  Future<void> printRecord(Map<String, dynamic> record) async {
    try {
      final bytes = await makePdf(record);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e')),
        );
      }
    }
  }

  Future<void> shareRecord(Map<String, dynamic> record) async {
    try {
      final bytes = await makePdf(record);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${record['number']}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share error: $e')),
        );
      }
    }
  }

  Future<void> showRecordActions(Map<String, dynamic> record) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetContext);
                editRecord(record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Share PDF'),
              onTap: () {
                Navigator.pop(sheetContext);
                shareRecord(record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Print / Preview PDF'),
              onTap: () {
                Navigator.pop(sheetContext);
                printRecord(record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(sheetContext);
                deleteRecord(record);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = types[selectedTab];
    final visible = records
        .where((r) => r['type'] == type)
        .toList();

    final total = visible.fold<double>(
      0,
      (sum, r) => sum + (double.tryParse('${r['amount']}') ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PR BUSINESS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 58,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: types.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: ChoiceChip(
                        label: Text(types[i]),
                        selected: selectedTab == i,
                        onSelected: (_) {
                          setState(() => selectedTab = i);
                        },
                      ),
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: Text('${types[selectedTab]} Total'),
                    trailing: Text(
                      money(total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text('No $type records yet.'),
                        )
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final record = visible[i];
                            final date =
                                '${record['date']}'.length >= 10
                                    ? '${record['date']}'.substring(0, 10)
                                    : '${record['date']}';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              child: ListTile(
                                onTap: () => showRecordActions(record),
                                leading: Icon(
                                  type == 'Expense'
                                      ? Icons.money_off
                                      : type == 'Income'
                                          ? Icons.attach_money
                                          : Icons.description,
                                ),
                                title: Text(
                                  '${record['customer'] ?? ''}',
                                ),
                                subtitle: Text(
                                  '${record['number']} • $date\n'
                                  '${record['description'] ?? ''}'
                                  '${record['status'] == 'Cancelled' ? '\nCANCELLED' : ''}',
                                ),
                                isThreeLine: true,
                                trailing: Text(
                                  money(record['amount']),
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
        label: Text('Add ${types[selectedTab]}'),
      ),
    );
  }
}
