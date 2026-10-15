import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const PRBusinessApp());
}

const categories = [
  'Invoice',
  'Estimate',
  'Quotation',
  'Income',
  'Expense',
];

const categoryPrefixes = {
  'Invoice': 'INV',
  'Estimate': 'EST',
  'Quotation': 'QUO',
  'Income': 'INC',
  'Expense': 'EXP',
};

class PRBusinessApp extends StatelessWidget {
  const PRBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PR Business',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> records = [];
  int selectedTab = 0;
  bool loading = true;

  final DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  String money(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  Future<void> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pr_business_records');

    if (saved != null) {
      try {
        records = List<Map<String, dynamic>>.from(
          (jsonDecode(saved) as List).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        );
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
    await prefs.setString('pr_business_records', jsonEncode(records));
  }

  String nextNumber(String type) {
    final prefix = categoryPrefixes[type]!;
    var maxNumber = 0;

    for (final record in records) {
      if (record['type'] == type) {
        final number = (record['number'] ?? '').toString();
        final parts = number.split('-');
        if (parts.length == 2) {
          final parsed = int.tryParse(parts[1]) ?? 0;
          if (parsed > maxNumber) maxNumber = parsed;
        }
      }
    }

    return '$prefix-${(maxNumber + 1).toString().padLeft(4, '0')}';
  }

  Future<void> addRecord() async {
    await showRecordDialog();
  }

  Future<void> editRecord(Map<String, dynamic> record) async {
    await showRecordDialog(record: record);
  }

  Future<void> showRecordDialog({
    Map<String, dynamic>? record,
  }) async {
    final isEditing = record != null;
    final customer = TextEditingController(
      text: record?['customer']?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: record?['phone']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: record?['description']?.toString() ?? '',
    );
    final amount = TextEditingController(
      text: record?['amount']?.toString() ?? '',
    );
    final notes = TextEditingController(
      text: record?['notes']?.toString() ?? '',
    );

    String type = record?['type']?.toString() ?? categories[selectedTab];

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) => AlertDialog(
          title: Text(isEditing ? 'Edit Record' : 'New $type'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isEditing)
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        refreshDialog(() => type = value);
                      }
                    },
                  ),
                TextField(
                  controller: customer,
                  decoration: const InputDecoration(
                    labelText: 'Customer / Name',
                  ),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Item / Description',
                  ),
                ),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                  ),
                ),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
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
                if (customer.text.trim().isEmpty ||
                    (double.tryParse(amount.text.trim()) ?? -1) < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a name and valid amount.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final parsedAmount = double.parse(amount.text.trim());

      setState(() {
        if (isEditing) {
          record['customer'] = customer.text.trim();
          record['phone'] = phone.text.trim();
          record['description'] = description.text.trim();
          record['amount'] = parsedAmount;
          record['notes'] = notes.text.trim();
        } else {
          records.add({
            'type': type,
            'number': nextNumber(type),
            'customer': customer.text.trim(),
            'phone': phone.text.trim(),
            'description': description.text.trim(),
            'amount': parsedAmount,
            'notes': notes.text.trim(),
            'date': DateTime.now().toIso8601String(),
          });
        }
      });

      await saveRecords();
    }

    customer.dispose();
    phone.dispose();
    description.dispose();
    amount.dispose();
    notes.dispose();
  }

  Future<void> deleteRecord(Map<String, dynamic> record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete record?'),
        content: const Text('This record will be deleted from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => records.remove(record));
      await saveRecords();
    }
  }

  Future<void> createPdf(Map<String, dynamic> record) async {
    final pdf = pw.Document();
    final type = record['type'].toString().toUpperCase();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              type,
              style: pw.TextStyle(
                fontSize: 25,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Text('Number: ${record['number']}'),
            pw.Text('Date: ${record['date'].toString().substring(0, 10)}'),
            pw.SizedBox(height: 12),
            pw.Text('Customer: ${record['customer']}'),
            if ((record['phone'] ?? '').toString().isNotEmpty)
              pw.Text('Phone: ${record['phone']}'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Description', 'Amount (INR)'],
              data: [
                [
                  record['description']?.toString() ?? '',
                  'Rs. ${(record['amount'] as num).toStringAsFixed(2)}',
                ],
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total: Rs. ${(record['amount'] as num).toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if ((record['notes'] ?? '').toString().isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Text('Notes: ${record['notes']}'),
            ],
            pw.Spacer(),
            pw.Divider(),
            pw.Center(child: pw.Text('Thank you')),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${record['number']}.pdf',
    );
  }

  Future<void> chooseAndCreateReport() async {
    DateTime start = DateTime.now();
    DateTime end = DateTime.now();
    String period = 'Daily';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Income & Expense Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: period,
                decoration: const InputDecoration(labelText: 'Period'),
                items: const [
                  DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                  DropdownMenuItem(
                    value: 'Date Range',
                    child: Text('Date Range'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) refresh(() => period = value);
                },
              ),
              const SizedBox(height: 12),
              if (period == 'Date Range') ...[
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) refresh(() => start = picked);
                  },
                  child: Text('From: ${start.toString().substring(0, 10)}'),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: end,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) refresh(() => end = picked);
                  },
                  child: Text('To: ${end.toString().substring(0, 10)}'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    if (period == 'Daily') {
      start = DateTime.now();
      start = DateTime(start.year, start.month, start.day);
      end = start.add(const Duration(days: 1)).subtract(
            const Duration(microseconds: 1),
          );
    } else if (period == 'Monthly') {
      final today = DateTime.now();
      start = DateTime(today.year, today.month, 1);
      end = DateTime(today.year, today.month + 1, 1).subtract(
        const Duration(microseconds: 1),
      );
    } else {
      if (end.isBefore(start)) {
        final temp = start;
        start = end;
        end = temp;
      }
      end = DateTime(end.year, end.month, end.day, 23, 59, 59);
    }

    final filtered = records.where((r) {
      final date = DateTime.tryParse(r['date'].toString());
      return date != null &&
          !date.isBefore(start) &&
          !date.isAfter(end);
    }).toList();

    final income = filtered
        .where((r) => r['type'] == 'Income')
        .fold<double>(0, (sum, r) => sum + (r['amount'] as num).toDouble());

    final expense = filtered
        .where((r) => r['type'] == 'Expense')
        .fold<double>(0, (sum, r) => sum + (r['amount'] as num).toDouble());

    final balance = income - expense;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$period Report'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('From: ${start.toString().substring(0, 10)}'),
              Text('To: ${end.toString().substring(0, 10)}'),
              const Divider(),
              Text('Income: ${money(income)}'),
              Text('Expense: ${money(expense)}'),
              Text(
                'Balance: ${money(balance)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ...filtered.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${r['type']} - ${r['customer']}'),
                  subtitle: Text('${r['number']} • ${r['date']}'),
                  trailing: Text(money(r['amount'])),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () => createReportPdf(
              period,
              start,
              end,
              filtered,
              income,
              expense,
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Share PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> createReportPdf(
    String period,
    DateTime start,
    DateTime end,
    List<Map<String, dynamic>> filtered,
    double income,
    double expense,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            '$period Income & Expense Report',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('From: ${start.toString().substring(0, 10)}'),
          pw.Text('To: ${end.toString().substring(0, 10)}'),
          pw.SizedBox(height: 12),
          pw.Text('Income: Rs. ${income.toStringAsFixed(2)}'),
          pw.Text('Expense: Rs. ${expense.toStringAsFixed(2)}'),
          pw.Text('Balance: Rs. ${(income - expense).toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Type', 'Number', 'Customer', 'Amount (INR)'],
            data: filtered
                .map(
                  (r) => [
                    r['type'].toString(),
                    r['number'].toString(),
                    r['customer'].toString(),
                    'Rs. ${(r['amount'] as num).toStringAsFixed(2)}',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'PR_Business_${period.replaceAll(' ', '_')}_Report.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = categories[selectedTab];
    final visible = records.where((r) => r['type'] == type).toList()
      ..sort(
        (a, b) => b['date'].toString().compareTo(a['date'].toString()),
      );

    final total = visible.fold<double>(
      0,
      (sum, r) => sum + (r['amount'] as num).toDouble(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('PR BUSINESS'),
        actions: [
          IconButton(
            tooltip: 'Reports',
            onPressed: chooseAndCreateReport,
            icon: const Icon(Icons.analytics_outlined),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: List.generate(categories.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(categories[i]),
                          selected: selectedTab == i,
                          onSelected: (_) => setState(() => selectedTab = i),
                        ),
                      );
                    }),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: Text('$type Total'),
                    trailing: Text(
                      money(total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(child: Text('No $type records yet.'))
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

                                onTap: () async {

                                  final action = await showModalBottomSheet<String>(

                                    context: context,

                                    builder: (sheetContext) => SafeArea(

                                      child: Wrap(

                                        children: [

                                          ListTile(

                                            leading: const Icon(Icons.edit),

                                            title: const Text('Edit'),

                                            onTap: () => Navigator.pop(

                                              sheetContext,

                                              'edit',

                                            ),

                                          ),

                                          ListTile(

                                            leading: const Icon(Icons.picture_as_pdf),

                                            title: const Text('Share PDF'),

                                            onTap: () => Navigator.pop(

                                              sheetContext,

                                              'pdf',

                                            ),

                                          ),

                                          ListTile(

                                            leading: const Icon(Icons.print),

                                            title: const Text('Print / Preview PDF'),

                                            onTap: () => Navigator.pop(

                                              sheetContext,

                                              'print',

                                            ),

                                          ),

                                          ListTile(

                                            leading: const Icon(Icons.delete_outline),

                                            title: const Text('Delete'),

                                            onTap: () => Navigator.pop(

                                              sheetContext,

                                              'delete',

                                            ),

                                          ),

                                        ],

                                      ),

                                    ),

                                  );

                                  if (!mounted) return;

                                  if (action == 'edit') {

                                    await editRecord(r);

                                  } else if (action == 'pdf') {

                                    await createPdf(r);

                                  } else if (action == 'print') {

                                    await createPdf(r);

                                  } else if (action == 'delete') {

                                    await deleteRecord(r);

                                  }

                                },

                                leading: const Icon(Icons.description_outlined),

                                title: Text(r['customer'].toString()),

                                subtitle: Text(

                                  '${r['number']} • ${r['date'].toString().substring(0, 10)}\n'

                                  '${r['description']}',

                                ),

                                isThreeLine: true,

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

        onPressed: addRecord,

        icon: const Icon(Icons.add),

        label: Text('Add $type'),

      ),

    );

  }

}
