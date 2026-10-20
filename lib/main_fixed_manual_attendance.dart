import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pr_business/gst_invoice.dart';

void main() => runApp(const PRBusinessApp());

const categories = ['Invoice', 'Tax Invoice', 'Estimate', 'Quotation', 'Income', 'Expense'];
const categoryPrefixes = {
  'Invoice': 'INV',
  'Tax Invoice': 'TIN',
  'Estimate': 'EST',
  'Quotation': 'QUO',
  'Income': 'INC',
  'Expense': 'EXP',
};

class PRBusinessApp extends StatelessWidget {
  const PRBusinessApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PR Business',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Keep the existing key so existing records remain readable.
  static const recordsKey = 'pr_business_records';
  static const stockKey = 'pr_business_stock_v1';
  static const businessKey = 'pr_business_profiles_v2';
  static const staffKey = 'pr_business_staff_v2';
  List<Map<String, dynamic>> records = [];
  List<Map<String, dynamic>> stock = [];
  List<Map<String, dynamic>> businesses = [];
  List<Map<String, dynamic>> staff = [];
  int selectedTab = 0;
  bool loading = true;

  String money(dynamic value) => '₹${((value as num?)?.toDouble() ?? 0).toStringAsFixed(2)}';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      // Keep SharedPreferences initialization inside try so an initialization
      // error cannot leave the home screen spinning forever.
      final prefs = await SharedPreferences.getInstance();

      final saved = prefs.getString(recordsKey);
      if (saved != null) {
        records = List<Map<String, dynamic>>.from(
          (jsonDecode(saved) as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }

      final savedStock = prefs.getString(stockKey);
      if (savedStock != null) {
        stock = List<Map<String, dynamic>>.from(
          (jsonDecode(savedStock) as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }

      final savedBusinesses = prefs.getString(businessKey);
      if (savedBusinesses != null) {
        businesses = List<Map<String, dynamic>>.from(
          (jsonDecode(savedBusinesses) as List)
              .map((e) => Map<String, dynamic>.from(e)),
        );
      }

      final savedStaff = prefs.getString(staffKey);
      if (savedStaff != null) {
        staff = List<Map<String, dynamic>>.from(
          (jsonDecode(savedStaff) as List)
              .map((e) => Map<String, dynamic>.from(e)),
        );
      }

      if (businesses.isEmpty) {
        businesses.add({
          'id': 'default',
          'name': 'PR BUSINESS',
          'address': '',
          'phone': '',
          'email': '',
          'gstin': '',
          'bankName': '',
          'accountName': '',
          'accountNumber': '',
          'ifsc': '',
          'default': true,
        });
      }
    } catch (e, stackTrace) {
      // Preserve saved data. Do not clear or overwrite preferences on failure.
      debugPrint('PR BUSINESS loadData error: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      // Always release the loading screen, even if storage initialization fails.
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(recordsKey, jsonEncode(records));
    await prefs.setString(stockKey, jsonEncode(stock));
    await prefs.setString(businessKey, jsonEncode(businesses));
    await prefs.setString(staffKey, jsonEncode(staff));
  }

  String nextNumber(String type) {
    final prefix = categoryPrefixes[type]!;
    var maxNumber = 0;
    for (final r in records.where((r) => r['type'] == type)) {
      final parts = (r['number'] ?? '').toString().split('-');
      if (parts.length == 2) maxNumber = maxNumber > (int.tryParse(parts[1]) ?? 0) ? maxNumber : (int.tryParse(parts[1]) ?? 0);
    }
    return '$prefix-${(maxNumber + 1).toString().padLeft(4, '0')}';
  }

  Map<String, dynamic> get defaultBusiness => businesses.firstWhere((b) => b['default'] == true, orElse: () => businesses.isNotEmpty ? businesses.first : {'id':'default','name':'PR BUSINESS'});

  Future<void> businessSettings() async {
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: const Text('Business Profiles'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...businesses.map((b) => Card(child: ListTile(
          title: Text((b['name'] ?? 'Business').toString()),
          subtitle: Text('${(b['address'] ?? '').toString()}\nGSTIN: ${(b['gstin'] ?? '').toString()}${b['default'] == true ? ' • Default' : ''}'),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(onSelected: (v) async {
            if (v == 'default') { for (final x in businesses) { x['default'] = x['id'] == b['id']; } await saveData(); refresh(() {}); }
            if (v == 'edit') { await editBusiness(b); refresh(() {}); }
            if (v == 'delete' && businesses.length > 1) { businesses.remove(b); if (b['default'] == true) businesses.first['default'] = true; await saveData(); refresh(() {}); }
          }, itemBuilder: (_) => const [PopupMenuItem(value:'default', child:Text('Set as default')), PopupMenuItem(value:'edit', child:Text('Edit')), PopupMenuItem(value:'delete', child:Text('Delete'))]),
        ))),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: () async { final b = <String,dynamic>{'id':DateTime.now().microsecondsSinceEpoch.toString(),'name':'','address':'','phone':'','email':'','gstin':'','bankName':'','accountName':'','accountNumber':'','ifsc':'','default':businesses.isEmpty}; await editBusiness(b, isNew:true); refresh(() {}); }, icon: const Icon(Icons.add), label: const Text('Add Business Profile')),
        const Text('Tip: select a business while creating an Invoice, Estimate or Quotation. Saved documents keep a snapshot of the selected profile.'),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    )));
  }

  Future<void> editBusiness(Map<String,dynamic> b, {bool isNew = false}) async {
    final fields = <String,TextEditingController>{
      'name':TextEditingController(text:(b['name']??'').toString()), 'address':TextEditingController(text:(b['address']??'').toString()),
      'phone':TextEditingController(text:(b['phone']??'').toString()), 'email':TextEditingController(text:(b['email']??'').toString()),
      'gstin':TextEditingController(text:(b['gstin']??'').toString()), 'bankName':TextEditingController(text:(b['bankName']??'').toString()),
      'accountName':TextEditingController(text:(b['accountName']??'').toString()), 'accountNumber':TextEditingController(text:(b['accountNumber']??'').toString()), 'ifsc':TextEditingController(text:(b['ifsc']??'').toString()),
    };
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(isNew?'Add Business':'Edit Business'), content: SizedBox(width:480, child: SingleChildScrollView(child: Column(mainAxisSize:MainAxisSize.min, children: [
      for (final entry in fields.entries) TextField(controller:entry.value, maxLines: entry.key=='address'?2:1, decoration:InputDecoration(labelText: {'name':'Business name','address':'Address','phone':'Phone','email':'Email','gstin':'GSTIN (optional)','bankName':'Bank name','accountName':'Account holder','accountNumber':'Account number','ifsc':'IFSC'}[entry.key])),
    ]))), actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false), child:const Text('Cancel')), FilledButton(onPressed:()=>Navigator.pop(ctx, fields['name']!.text.trim().isNotEmpty), child:const Text('Save'))]));
    if (ok == true) { for (final e in fields.entries) { b[e.key] = e.value.text.trim(); } if (isNew) businesses.add(b); await saveData(); if (mounted) setState(() {}); }
    for (final c in fields.values) { c.dispose(); }
  }

  String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _attendanceFor(Map<String, dynamic> person, DateTime day) {
    final all = Map<String, dynamic>.from((person['attendance'] as Map?) ?? {});
    return Map<String, dynamic>.from((all[_dateKey(day)] as Map?) ?? {'status': 'Absent', 'checkIn': '', 'checkOut': '', 'breakMinutes': 0, 'overtimeHours': 0.0});
  }

  Future<void> _saveAttendance(Map<String, dynamic> person, DateTime day, Map<String, dynamic> item) async {
    final all = Map<String, dynamic>.from((person['attendance'] as Map?) ?? {});
    all[_dateKey(day)] = item;
    person['attendance'] = all;
    await saveData();
    if (mounted) setState(() {});
  }

  double _hoursFor(Map<String, dynamic> item) {
    final a = DateTime.tryParse((item['checkIn'] ?? '').toString());
    final b = DateTime.tryParse((item['checkOut'] ?? '').toString());
    if (a == null || b == null || !b.isAfter(a)) return 0;
    final mins = b.difference(a).inMinutes;
    return (mins > 0 ? mins / 60 : 0);
  }

  double _monthPayroll(Map<String, dynamic> person, DateTime month) {
    final attendance = Map<String, dynamic>.from((person['attendance'] as Map?) ?? {});
    double payableDays = 0, overtime = 0;
    for (final e in attendance.entries) {
      final date = DateTime.tryParse(e.key);
      if (date == null || date.year != month.year || date.month != month.month) continue;
      final a = Map<String, dynamic>.from(e.value as Map);
      final status = (a['status'] ?? 'Absent').toString();
      if (status == 'Present') payableDays += 1;
      if (status == 'Half-day') payableDays += .5;
      final hours = _hoursFor(a);
      overtime += hours > 8.5 ? hours - 8.5 : 0;
    }
    final rate = (person['rate'] as num?)?.toDouble() ?? 0;
    final base = (person['payType'] == 'Daily wage') ? rate * payableDays : (rate / 26) * payableDays;
    final otPay = overtime * ((person['overtimeRate'] as num?)?.toDouble() ?? 0);
    final transactions = List<Map<String, dynamic>>.from((person['moneyTransactions'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    double deductions = 0;
    for (final t in transactions) {
      final date = DateTime.tryParse((t['date'] ?? '').toString());
      if (date == null || date.year != month.year || date.month != month.month) continue;
      if (t['type'] == 'Advance' || t['type'] == 'Loan repayment' || t['type'] == 'Other deduction') deductions += (t['amount'] as num?)?.toDouble() ?? 0;
    }
    return base + otPay - deductions;
  }

  Future<void> manageStaff() async {
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: const Text('Staff Management'),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...staff.map((s) => Card(margin: const EdgeInsets.symmetric(vertical: 5), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text((s['name'] ?? 'Staff').toString(), style: Theme.of(ctx).textTheme.titleMedium, softWrap: true),
          const SizedBox(height: 4),
          Text('${s['payType']} • Rate ${money(s['rate'])} • OT ${money(s['overtimeRate'])}/hr', softWrap: true),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.start, spacing: 4, runSpacing: 4, children: [
            OutlinedButton.icon(onPressed: () async { await _staffAttendance(s); refresh(() {}); }, icon: const Icon(Icons.calendar_month), label: const Text('Attendance')),
            OutlinedButton.icon(onPressed: () async { await _staffMoney(s); refresh(() {}); }, icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('Advance / Loan')),
            IconButton(tooltip: 'Edit staff', icon: const Icon(Icons.edit), onPressed: () async { await editStaff(s); refresh(() {}); }),
            IconButton(tooltip: 'Delete staff', icon: const Icon(Icons.delete_outline), onPressed: () async { staff.remove(s); await saveData(); refresh(() {}); }),
          ]),
        ])))),
        FilledButton.icon(onPressed: () async { final s = <String,dynamic>{'id':DateTime.now().microsecondsSinceEpoch.toString(),'name':'','payType':'Monthly salary','rate':0.0,'overtimeRate':0.0,'attendance':<String,dynamic>{},'moneyTransactions':<dynamic>[]}; await editStaff(s,isNew:true); refresh(() {}); }, icon: const Icon(Icons.add), label: const Text('Add Staff')),
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('Attendance, check-in/out, overtime, advances and loan deductions are saved on this device.')),
      ]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    )));
  }

  Future<void> _staffAttendance(Map<String, dynamic> person) async {
    DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
    DateTime selected = DateTime.now();
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) {
      final item = _attendanceFor(person, selected);
      final hours = _hoursFor(item);
      final attendance = Map<String, dynamic>.from((person['attendance'] as Map?) ?? {});
      final days = DateTime(month.year, month.month + 1, 0).day;
      final rate = (person['rate'] as num?)?.toDouble() ?? 0;
      final allEntries = attendance.entries.where((e) { final d = DateTime.tryParse(e.key); return d != null && d.year == month.year && d.month == month.month; }).toList();
      double present = 0, ot = 0;
      for (final e in allEntries) { final v = Map<String,dynamic>.from(e.value as Map); if (v['status']=='Present') present++; if (v['status']=='Half-day') present += .5; ot += _hoursFor(v)>8.5 ? _hoursFor(v)-8.5 : 0; }
      final base = person['payType']=='Daily wage' ? rate*present : rate/26*present;
      final otPay = ot*((person['overtimeRate'] as num?)?.toDouble()??0);
      final net = _monthPayroll(person, month);
      return AlertDialog(title: Text('${person['name']} • Attendance'), content: SizedBox(width: 580, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [IconButton(onPressed: () => refresh(() { month=DateTime(month.year,month.month-1); selected=DateTime(month.year,month.month,selected.day.clamp(1,DateTime(month.year,month.month+1,0).day)); }), icon: const Icon(Icons.chevron_left)), Expanded(child: Center(child: Text('${month.year}-${month.month.toString().padLeft(2,'0')}', style: const TextStyle(fontWeight: FontWeight.bold)))), IconButton(onPressed: () => refresh(() { month=DateTime(month.year,month.month+1); selected=DateTime(month.year,month.month,selected.day.clamp(1,DateTime(month.year,month.month+1,0).day)); }), icon: const Icon(Icons.chevron_right))]),
        const Row(children: [Expanded(child: Center(child: Text('Mon', style: TextStyle(fontSize: 11)))),Expanded(child: Center(child: Text('Tue', style: TextStyle(fontSize: 11)))),Expanded(child: Center(child: Text('Wed', style: TextStyle(fontSize: 11)))),Expanded(child: Center(child: Text('Thu', style: TextStyle(fontSize: 11)))),Expanded(child: Center(child: Text('Fri', style: TextStyle(fontSize: 11)))),Expanded(child: Center(child: Text('Sat', style: TextStyle(fontSize: 11)))),Expanded(child: Center(child: Text('Sun', style: TextStyle(fontSize: 11))))]),
        const SizedBox(height: 4),
        GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 3, crossAxisSpacing: 3, childAspectRatio: 1.05, children: [
          ...List.generate((DateTime(month.year, month.month, 1).weekday - 1), (_) => const SizedBox.shrink()),
          ...List.generate(days, (i) { final d=DateTime(month.year,month.month,i+1); final a=_attendanceFor(person,d); final status=(a['status']??'Absent').toString(); final label=status=='Present'?'P':status=='Half-day'?'½':status=='Leave'?'L':'A'; return OutlinedButton(onPressed: () => refresh(() => selected=d), style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: _dateKey(d)==_dateKey(selected)?Theme.of(ctx).colorScheme.primaryContainer:null), child: FittedBox(fit: BoxFit.scaleDown, child: Text('${d.day}\n$label', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)))); }),
        ]),
        const SizedBox(height: 10), Text('Selected date: ${_dateKey(selected)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        DropdownButtonFormField<String>(value: (item['status']??'Absent').toString(), decoration: const InputDecoration(labelText:'Attendance status'), items: const [DropdownMenuItem(value:'Present',child:Text('Present')),DropdownMenuItem(value:'Absent',child:Text('Absent')),DropdownMenuItem(value:'Leave',child:Text('Leave')),DropdownMenuItem(value:'Half-day',child:Text('Half-day'))], onChanged: (v) async { if(v!=null){ item['status']=v; await _saveAttendance(person,selected,item); refresh((){}); }}),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('checkin-${_dateKey(selected)}-${item['checkIn']}'),
          initialValue: (item['checkIn'] ?? '').toString().isEmpty ? '' : (DateTime.tryParse(item['checkIn'].toString())?.toLocal().toString().substring(11,16) ?? ''),
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(labelText: 'Check-in time (HH:mm)', hintText: '09:00', helperText: 'Enter time manually in 24-hour format'),
          onChanged: (v) { final m = RegExp(r'^(?:[01]?[0-9]|2[0-3]):[0-5][0-9]$').firstMatch(v.trim()); if (m != null) { final parts=v.trim().split(':'); item['checkIn']=DateTime(selected.year,selected.month,selected.day,int.parse(parts[0]),int.parse(parts[1])).toIso8601String(); item['status']='Present'; } else if (v.trim().isEmpty) { item['checkIn']=''; } refresh((){}); },
        ),
        TextFormField(
          key: ValueKey('checkout-${_dateKey(selected)}-${item['checkOut']}'),
          initialValue: (item['checkOut'] ?? '').toString().isEmpty ? '' : (DateTime.tryParse(item['checkOut'].toString())?.toLocal().toString().substring(11,16) ?? ''),
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(labelText: 'Check-out time (HH:mm)', hintText: '17:30', helperText: 'Enter time manually in 24-hour format'),
          onChanged: (v) { final m = RegExp(r'^(?:[01]?[0-9]|2[0-3]):[0-5][0-9]$').firstMatch(v.trim()); if (m != null) { final parts=v.trim().split(':'); item['checkOut']=DateTime(selected.year,selected.month,selected.day,int.parse(parts[0]),int.parse(parts[1])).toIso8601String(); item['status']='Present'; } else if (v.trim().isEmpty) { item['checkOut']=''; } refresh((){}); },
        ),
        Text('Net working time: ${hours.toStringAsFixed(2)} hours • Suggested OT: ${(hours-8.5>0?hours-8.5:0).toStringAsFixed(2)} hours'),
        const Text('Enter both times as HH:mm (24-hour clock), then tap Save selected day. Standard day: 8.5 hours; OT is calculated automatically.'),
        FilledButton(onPressed: () async { await _saveAttendance(person,selected,item); refresh((){}); }, child: const Text('Save selected day')),
        const Divider(), Text('Monthly summary • Present days: ${present.toStringAsFixed(1)} / 26'), Text('Attendance salary: ${money(base)}'), Text('Overtime: ${ot.toStringAsFixed(2)} hours • ${money(otPay)}'), Text('Net after recorded deductions: ${money(net)}'),
        FilledButton.icon(onPressed: () async { final doc=pw.Document(); doc.addPage(pw.Page(build:(c)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Text('PR BUSINESS - SALARY SLIP',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:10),pw.Text('Employee: ${person['name']}'),pw.Text('Month: ${month.year}-${month.month.toString().padLeft(2,'0')}'),pw.Text('Pay type: ${person['payType']}'),pw.Text('Present equivalent days: ${present.toStringAsFixed(1)}'),pw.Text('Attendance salary: ${money(base)}'),pw.Text('Overtime hours: ${ot.toStringAsFixed(2)}'),pw.Text('Overtime amount: ${money(otPay)}'),pw.Text('Deductions: ${money(base+otPay-net)}'),pw.Divider(),pw.Text('Net salary: ${money(net)}',style:pw.TextStyle(fontSize:16,fontWeight:pw.FontWeight.bold))]))); await Printing.sharePdf(bytes:await doc.save(),filename:'Salary_Slip_${person['name']}_${month.year}_${month.month}.pdf'); }, icon: const Icon(Icons.picture_as_pdf), label: const Text('Share Salary Slip PDF')),
      ]))), actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]);
    }));
  }

  Future<void> _staffMoney(Map<String, dynamic> person) async {
    final amount=TextEditingController(); final note=TextEditingController(); String type='Advance'; String date=_dateKey(DateTime.now());
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(title:Text('Advance / Loan • ${person['name']}'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'Transaction type'),items:const [DropdownMenuItem(value:'Advance',child:Text('Advance given / salary advance deduction')),DropdownMenuItem(value:'Loan repayment',child:Text('Loan repayment deduction')),DropdownMenuItem(value:'Other deduction',child:Text('Other deduction')),DropdownMenuItem(value:'Loan issued',child:Text('New loan given (balance only'))],onChanged:(v){if(v!=null)refresh(()=>type=v);}),TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount (₹)')),TextField(controller:note,decoration:const InputDecoration(labelText:'Note / loan details')),const SizedBox(height:8),Text('Choose the amount deducted this month for Advance, Loan repayment or Other deduction. “Loan issued” records a balance but does not deduct salary.') ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,(double.tryParse(amount.text)??0)>0),child:const Text('Save'))])));
    if(ok==true){final list=List<Map<String,dynamic>>.from((person['moneyTransactions'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e as Map)));list.add({'id':DateTime.now().microsecondsSinceEpoch.toString(),'type':type,'amount':double.parse(amount.text),'note':note.text.trim(),'date':date});person['moneyTransactions']=list;await saveData();if(mounted)setState((){});}
    amount.dispose();note.dispose();
  }

  Future<void> editStaff(Map<String, dynamic> s, {bool isNew=false}) async {
    final name=TextEditingController(text:(s['name']??'').toString()); final rate=TextEditingController(text:(s['rate']??0).toString()); final overtime=TextEditingController(text:(s['overtimeRate']??0).toString()); String payType=(s['payType']??'Monthly salary').toString();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(title:Text(isNew?'Add Staff':'Edit Staff'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Staff name')),DropdownButtonFormField<String>(value:payType,decoration:const InputDecoration(labelText:'Pay type'),items:const [DropdownMenuItem(value:'Monthly salary',child:Text('Monthly salary')),DropdownMenuItem(value:'Daily wage',child:Text('Daily wage'))],onChanged:(v){if(v!=null)refresh(()=>payType=v);}),TextField(controller:rate,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:payType=='Daily wage'?'Daily wage amount':'Monthly salary')),TextField(controller:overtime,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Overtime rate per hour'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,name.text.trim().isNotEmpty&&(double.tryParse(rate.text)??-1)>=0&&(double.tryParse(overtime.text)??-1)>=0),child:const Text('Save'))])));
    if(ok==true){s['name']=name.text.trim();s['payType']=payType;s['rate']=double.parse(rate.text);s['overtimeRate']=double.parse(overtime.text);s.putIfAbsent('attendance',()=> <String,dynamic>{});s.putIfAbsent('moneyTransactions',()=> <dynamic>[]);if(isNew)staff.add(s);await saveData();if(mounted)setState((){});} name.dispose();rate.dispose();overtime.dispose();
  }

  Future<void> recordPayment(Map<String,dynamic> r) async {
    final amount=TextEditingController(); final note=TextEditingController();
    final total=(r['amount'] as num?)?.toDouble()??0; final paid=(r['receivedAmount'] as num?)?.toDouble()??0; final due=(total-paid).clamp(0.0,total);
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('Record Payment • ${r['number']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[Text('Invoice total: ${money(total)}\nReceived: ${money(paid)}\nOutstanding: ${money(due)}'),TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount received')),TextField(controller:note,decoration:const InputDecoration(labelText:'Payment note / method (optional)'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:(){final v=double.tryParse(amount.text)??0;if(v>0&&v<=due)Navigator.pop(ctx,true);else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Enter an amount greater than zero and not above ${money(due)}.')));},child:const Text('Save Payment'))]));
    if (ok == true) {
      final v = double.parse(amount.text);
      final paymentDate = DateTime.now().toIso8601String();
      final paymentId = DateTime.now().microsecondsSinceEpoch.toString();
      r['receivedAmount'] = paid + v;
      final payments = List<Map<String, dynamic>>.from(
        (r['payments'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      payments.add({'id': paymentId, 'date': paymentDate, 'amount': v, 'note': note.text.trim()});
      r['payments'] = payments;
      // Record each received payment as Income, not the full invoice value.
      // The link lets future reports/audits identify its source invoice.
      records.add({
        'type': 'Income',
        'number': nextNumber('Income'),
        'customer': (r['customer'] ?? '').toString(),
        'description': 'Payment received for ${(r['number'] ?? '').toString()}',
        'amount': v,
        'date': paymentDate,
        'notes': note.text.trim(),
        'linkedInvoiceNumber': (r['number'] ?? '').toString(),
        'linkedInvoiceType': (r['type'] ?? '').toString(),
        'paymentId': paymentId,
      });
      if (mounted) setState(() {});
      await saveData();
    }
    amount.dispose();note.dispose();
  }

  Future<void> addRecord() => showRecordDialog();
  Future<void> editRecord(Map<String, dynamic> r) => showRecordDialog(record: r);

  Future<void> showRecordDialog({Map<String, dynamic>? record}) async {
    final editing = record != null;
    String type = record?['type']?.toString() ?? categories[selectedTab];
    String selectedBusinessId = (record?['businessId'] ?? defaultBusiness['id']).toString();
    final customer = TextEditingController(text: record?['customer']?.toString() ?? '');
    final phone = TextEditingController(text: record?['phone']?.toString() ?? '');
    final shipTo = TextEditingController(text: record?['shipTo']?.toString() ?? '');
    final notes = TextEditingController(text: record?['notes']?.toString() ?? '');
    final oldItems = (record?['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? <Map<String, dynamic>>[];
    final items = oldItems.isNotEmpty
        ? oldItems
        : <Map<String, dynamic>>[{
            'stockId': null,
            'description': record?['description']?.toString() ?? '',
            'quantity': 1.0,
            'rate': (record?['amount'] as num?)?.toDouble() ?? 0.0,
            'total': (record?['amount'] as num?)?.toDouble() ?? 0.0,
          }];
    void recalc(Map<String, dynamic> item) {
      item['total'] = ((item['quantity'] as num).toDouble()) * ((item['rate'] as num).toDouble());
    }
    double total() => items.fold<double>(0, (s, i) => s + ((i['total'] as num?)?.toDouble() ?? 0));
    // Keep one controller per line-item map for the entire dialog lifetime.
    // Creating controllers inside List.generate resets text/selection on rebuild.
    final descriptionControllers = <Map<String, dynamic>, TextEditingController>{};
    final quantityControllers = <Map<String, dynamic>, TextEditingController>{};
    final rateControllers = <Map<String, dynamic>, TextEditingController>{};
    void ensureItemControllers(Map<String, dynamic> item) {
      descriptionControllers.putIfAbsent(item, () => TextEditingController(text: (item['description'] ?? '').toString()));
      quantityControllers.putIfAbsent(item, () => TextEditingController(text: (item['quantity'] ?? 1).toString()));
      rateControllers.putIfAbsent(item, () => TextEditingController(text: (item['rate'] ?? 0).toString()));
    }
    for (final item in items) { ensureItemControllers(item); }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, refresh) => AlertDialog(
        title: Text(editing ? 'Edit ${record['type']}' : 'New $type'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!editing) DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) { if (v != null) refresh(() => type = v); },
            ),
            if (['Invoice','Tax Invoice','Estimate','Quotation'].contains(type)) DropdownButtonFormField<String>(
              value: businesses.any((b) => b['id'].toString() == selectedBusinessId) ? selectedBusinessId : defaultBusiness['id'].toString(),
              decoration: const InputDecoration(labelText: 'Business Profile'),
              items: businesses.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text((b['name'] ?? 'Business').toString()))).toList(),
              onChanged: (v) { if (v != null) refresh(() => selectedBusinessId = v); },
            ),
            TextField(controller: customer, decoration: const InputDecoration(labelText: 'Customer / Name')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
            if (type == 'Tax Invoice') TextField(controller: shipTo, maxLines: 2, decoration: const InputDecoration(labelText: 'Ship To address (optional)')),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text('Line items', style: Theme.of(context).textTheme.titleMedium)),
            ...List.generate(items.length, (index) {
              final item = items[index];
              ensureItemControllers(item);
              final desc = descriptionControllers[item]!;
              final qty = quantityControllers[item]!;
              final rate = rateControllers[item]!;
              return Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
                if (['Invoice', 'Tax Invoice', 'Estimate', 'Quotation'].contains(type) && stock.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    value: item['stockId']?.toString(),
                    decoration: const InputDecoration(labelText: 'Select stock item (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Manual description')),
                      ...stock.map((s) => DropdownMenuItem<String?>(value: s['id'].toString(), child: Text('${s['name']} (Stock: ${s['quantity']})'))),
                    ],
                          onChanged: (v) => refresh(() {
                      item['stockId'] = v;
                      if (v != null) {
                        final s = stock.firstWhere((x) => x['id'].toString() == v);
                        item['description'] = s['name'];
                        item['rate'] = (s['sellingRate'] as num).toDouble();
                        descriptionControllers[item]!.text = (s['name'] ?? '').toString();
                        rateControllers[item]!.text = item['rate'].toString();
                      }
                    }),
                  ),
                TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description / Item'), onChanged: (v) { item['description'] = v; }),
                Row(children: [
                  Expanded(child: TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity'), onChanged: (v) => refresh(() { item['quantity'] = double.tryParse(v) ?? 0; recalc(item); }))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rate'), onChanged: (v) => refresh(() { item['rate'] = double.tryParse(v) ?? 0; recalc(item); }))),
                ]),
                Align(alignment: Alignment.centerRight, child: Text('Line total: ${money(item['total'])}')),
                if (items.length > 1) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => refresh(() => items.removeAt(index)), icon: const Icon(Icons.remove_circle_outline), label: const Text('Remove item'))),
              ])));
            }),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
              onPressed: () => refresh(() {
                final newItem = <String, dynamic>{'stockId': null, 'description': '', 'quantity': 1.0, 'rate': 0.0, 'total': 0.0};
                ensureItemControllers(newItem);
                items.add(newItem);
              }),
              icon: const Icon(Icons.add), label: const Text('Add line item'),
            )),
            Align(alignment: Alignment.centerRight, child: Text('Grand Total: ${money(total())}', style: const TextStyle(fontWeight: FontWeight.bold))),
            TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          ],
        ))),
        actions: [
          TextButton(onPressed: () async {
            for (final i in items) { i['total'] = (i['quantity'] as num).toDouble() * (i['rate'] as num).toDouble(); }
            final previewRecord = <String,dynamic>{'type':type,'number':record?['number'] ?? nextNumber(type),'date':record?['date'] ?? DateTime.now().toIso8601String(),'customer':customer.text.trim(),'phone':phone.text.trim(),'shipTo':shipTo.text.trim(),'items':items.map((i)=>Map<String,dynamic>.from(i)).toList(),'amount':total(),'notes':notes.text.trim(),'business':Map<String,dynamic>.from(businesses.firstWhere((b)=>b['id'].toString()==selectedBusinessId,orElse:()=>defaultBusiness))};
            await showDocumentPreview(previewRecord);
          }, child: const Text('Preview')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (customer.text.trim().isEmpty || items.isEmpty || items.any((i) => (i['quantity'] as num) <= 0 || (i['rate'] as num) < 0)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a name, positive quantity and valid rate.')));
              return;
            }
            for (final i in items) { i['total'] = (i['quantity'] as num).toDouble() * (i['rate'] as num).toDouble(); }
            Navigator.pop(dialogContext, true);
          }, child: const Text('Save')),
        ],
      )),
    );

    if (ok == true && mounted) {
      final oldStockItems = (record?['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? <Map<String, dynamic>>[];
      // Restore stock consumed by the previous version of this invoice before replacing it.
      if (editing && ['Invoice','Tax Invoice'].contains(type)) {
        for (final old in oldStockItems) {
          final id = old['stockId']?.toString();
          if (id != null) {
            final s = stock.where((x) => x['id'].toString() == id);
            if (s.isNotEmpty) s.first['quantity'] = ((s.first['quantity'] as num).toDouble() + (old['quantity'] as num).toDouble());
          }
        }
      }
      if (['Invoice','Tax Invoice'].contains(type)) {
        for (final item in items) {
          final id = item['stockId']?.toString();
          if (id != null) {
            final found = stock.where((s) => s['id'].toString() == id);
            if (found.isNotEmpty && (found.first['quantity'] as num).toDouble() < (item['quantity'] as num).toDouble()) {
              if (editing) {
                for (final old in oldStockItems) {
                  final oldId = old['stockId']?.toString();
                  if (oldId != null) {
                    final f = stock.where((s) => s['id'].toString() == oldId);
                    if (f.isNotEmpty) f.first['quantity'] = ((f.first['quantity'] as num).toDouble() - (old['quantity'] as num).toDouble());
                  }
                }
              }
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Insufficient stock for ${found.isNotEmpty ? found.first['name'] : 'item'}.')));
              customer.dispose(); phone.dispose(); shipTo.dispose(); notes.dispose();
              return;
            }
          }
        }
        for (final item in items) {
          final id = item['stockId']?.toString();
          if (id != null) {
            final f = stock.where((s) => s['id'].toString() == id);
            if (f.isNotEmpty) f.first['quantity'] = ((f.first['quantity'] as num).toDouble() - (item['quantity'] as num).toDouble());
          }
        }
      }
      final amount = total();
      setState(() {
        if (editing) {
          record['customer'] = customer.text.trim();
          record['phone'] = phone.text.trim();
          record['shipTo'] = shipTo.text.trim();
          record['businessId'] = selectedBusinessId;
          record['business'] = Map<String,dynamic>.from(businesses.firstWhere((b) => b['id'].toString() == selectedBusinessId, orElse: () => defaultBusiness));
          record['items'] = items;
          record['description'] = items.map((i) => i['description']).join(', ');
          record['amount'] = amount;
          record['notes'] = notes.text.trim();
        } else {
          records.add({
            'type': type, 'number': nextNumber(type), 'customer': customer.text.trim(),
            'phone': phone.text.trim(), 'shipTo': shipTo.text.trim(), 'items': items,
            'description': items.map((i) => i['description']).join(', '),
            'amount': amount, 'notes': notes.text.trim(), 'date': DateTime.now().toIso8601String(),
            'businessId': selectedBusinessId, 'business': Map<String,dynamic>.from(businesses.firstWhere((b) => b['id'].toString() == selectedBusinessId, orElse: () => defaultBusiness)), 'receivedAmount': 0.0, 'payments': <Map<String,dynamic>>[],
          });
        }
      });
      await saveData();
    }
    for (final c in descriptionControllers.values) { c.dispose(); }
    for (final c in quantityControllers.values) { c.dispose(); }
    for (final c in rateControllers.values) { c.dispose(); }
    customer.dispose(); phone.dispose(); shipTo.dispose(); notes.dispose();
  }

  Future<void> showDocumentPreview(Map<String,dynamic> r) async {
    
  if (r['type'] == 'Tax Invoice') {
    final b = Map<String, dynamic>.from(
      r['business'] as Map? ?? <String, dynamic>{},
    );

    final invoiceDate = DateTime.tryParse(
      '${r['date'] ?? ''}',
    ) ?? DateTime.now();

    final invoiceItems = (r['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GSTInvoicePreview(
          businessName: '${b['name'] ?? 'PR BUSINESS'}',
          address: '${b['address'] ?? ''}',
          phone: '${b['phone'] ?? ''}',
          gstin: '${b['gstin'] ?? ''}',
          invoiceNumber: '${r['number'] ?? ''}',
          invoiceDate: invoiceDate,
          customerName: '${r['customer'] ?? ''}',
          customerAddress: '${r['shipTo'] ?? ''}',
          customerGstin: '${r['customerGstin'] ?? ''}',
          items: invoiceItems,
          receivedAmount:
              (r['receivedAmount'] as num?)?.toDouble() ?? 0,
        ),
      ),
    );

    return;
  }

    final items=(r['items'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    final business=Map<String,dynamic>.from((r['business'] as Map?)?.cast<String,dynamic>() ?? defaultBusiness);
    final total=(r['amount'] as num?)?.toDouble()??0; final received=(r['receivedAmount'] as num?)?.toDouble()??0;
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text('${r['type']} Preview'),content:SizedBox(width:560,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      if(r['type']=='Tax Invoice') Text((business['name']??'').toString(),style:Theme.of(context).textTheme.titleLarge),if(r['type']=='Tax Invoice' && (business['address']??'').toString().isNotEmpty)Text(business['address'].toString()),if(r['type']=='Tax Invoice' && (business['phone']??'').toString().isNotEmpty)Text('Phone: ${business['phone']}'),if(r['type']=='Tax Invoice' && (business['gstin']??'').toString().isNotEmpty)Text('GSTIN: ${business['gstin']}'),const Divider(),Text('${r['type']}  •  ${r['number']}',style:const TextStyle(fontWeight:FontWeight.bold)),Text('Date: ${(r['date']??'').toString().substring(0,10)}'),Text('Bill To: ${r['customer']}'),if((r['phone']??'').toString().isNotEmpty)Text('Phone: ${r['phone']}'),if(r['type']=='Tax Invoice' && (r['shipTo']??'').toString().isNotEmpty)Text('Ship To: ${r['shipTo']}'),const SizedBox(height:12),const Row(children:[Expanded(child:Text('Item',style:TextStyle(fontWeight:FontWeight.bold))),Text('Qty  Rate  Amount',style:TextStyle(fontWeight:FontWeight.bold))]),const Divider(),...items.map((i)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Expanded(child:Text((i['description']??'').toString())),Text('${i['quantity']}  ${money(i['rate'])}  ${money(i['total'])}')]))),const Divider(),Align(alignment:Alignment.centerRight,child:Text('Grand Total: ${money(total)}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),if(['Invoice','Tax Invoice'].contains(r['type']))Align(alignment:Alignment.centerRight,child:Text('Received: ${money(received)}   Balance Due: ${money((total-received).clamp(0.0,total))}')),if((r['notes']??'').toString().isNotEmpty)Text('Notes: ${r['notes']}'),const SizedBox(height:16),const Center(child:Text('Thank you'))]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]));
  }

  Future<void> showStockDialog({Map<String, dynamic>? item}) async {
    final editing = item != null;
    final code = TextEditingController(text: item?['code']?.toString() ?? '');
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final category = TextEditingController(text: item?['category']?.toString() ?? '');
    final unit = TextEditingController(text: item?['unit']?.toString() ?? 'Nos');
    final purchase = TextEditingController(text: item?['purchaseRate']?.toString() ?? '');
    final selling = TextEditingController(text: item?['sellingRate']?.toString() ?? '');
    final quantity = TextEditingController(text: item?['quantity']?.toString() ?? '');
    final minimum = TextEditingController(text: item?['minimum']?.toString() ?? '0');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(editing ? 'Edit Stock Item' : 'New Stock Item'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: code, decoration: const InputDecoration(labelText: 'Item Code')),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Item Name')),
        TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
        TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit (Nos/Meter/Kg)')),
        TextField(controller: purchase, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Purchase Rate')),
        TextField(controller: selling, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Selling Rate')),
        TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Available Stock')),
        TextField(controller: minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Minimum Stock Alert')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (name.text.trim().isEmpty || (double.tryParse(purchase.text) ?? -1) < 0 || (double.tryParse(selling.text) ?? -1) < 0 || (double.tryParse(quantity.text) ?? -1) < 0 || (double.tryParse(minimum.text) ?? -1) < 0) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter item name and valid non-negative numbers.')));
            return;
          }
          Navigator.pop(ctx, true);
        }, child: const Text('Save')),
      ],
    ));
    if (ok == true && mounted) {
      setState(() {
        if (editing) {
          item['code'] = code.text.trim(); item['name'] = name.text.trim(); item['category'] = category.text.trim();
          item['unit'] = unit.text.trim(); item['purchaseRate'] = double.parse(purchase.text);
          item['sellingRate'] = double.parse(selling.text); item['quantity'] = double.parse(quantity.text); item['minimum'] = double.parse(minimum.text);
        } else {
          stock.add({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'code': code.text.trim(), 'name': name.text.trim(),
            'category': category.text.trim(), 'unit': unit.text.trim().isEmpty ? 'Nos' : unit.text.trim(),
            'purchaseRate': double.parse(purchase.text), 'sellingRate': double.parse(selling.text),
            'quantity': double.parse(quantity.text), 'minimum': double.parse(minimum.text)});
        }
      });
      await saveData();
    }
    code.dispose(); name.dispose(); category.dispose(); unit.dispose(); purchase.dispose(); selling.dispose(); quantity.dispose(); minimum.dispose();
  }

  Future<void> deleteRecord(Map<String, dynamic> record) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete record?'),
      content: const Text('Delete this record from this device? Stock previously deducted by this invoice will be returned.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) {
      if (record['type'] == 'Invoice') {
        for (final item in ((record['items'] as List?) ?? [])) {
          final id = item['stockId']?.toString();
          if (id != null) {
            final f = stock.where((s) => s['id'].toString() == id);
            if (f.isNotEmpty) f.first['quantity'] = ((f.first['quantity'] as num).toDouble() + (item['quantity'] as num).toDouble());
          }
        }
      }
      setState(() => records.remove(record));
      await saveData();
    }
  }

  Future<void> createPdf(Map<String, dynamic> r) async {
    final pdf = pw.Document();
    final items = (r['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
        [{'description': r['description'] ?? '', 'quantity': 1, 'rate': r['amount'] ?? 0, 'total': r['amount'] ?? 0}];
    final business = Map<String,dynamic>.from((r['business'] as Map?)?.cast<String,dynamic>() ?? defaultBusiness);
    final received = (r['receivedAmount'] as num?)?.toDouble() ?? 0;
    pdf.addPage(pw.MultiPage(build: (ctx) => [
      if (r['type'] == 'Tax Invoice' && (business['name'] ?? '').toString().isNotEmpty) pw.Text(business['name'].toString(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      if (r['type'] == 'Tax Invoice' && (business['address'] ?? '').toString().isNotEmpty) pw.Text(business['address'].toString()),
      if (r['type'] == 'Tax Invoice' && (business['phone'] ?? '').toString().isNotEmpty) pw.Text('Phone: ${business['phone']}'),
      if (r['type'] == 'Tax Invoice' && (business['gstin'] ?? '').toString().isNotEmpty) pw.Text('GSTIN: ${business['gstin']}'),
      pw.SizedBox(height: 8),
      pw.Text(r['type'].toString().toUpperCase(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
      pw.Divider(),
      pw.Text('Number: ${r['number']}'),
      pw.Text('Date: ${(r['date'] ?? '').toString().substring(0, 10)}'),
      pw.Text('Customer: ${r['customer']}'),
      if ((r['phone'] ?? '').toString().isNotEmpty) pw.Text('Phone: ${r['phone']}'),
      if (r['type'] == 'Tax Invoice' && (r['shipTo'] ?? '').toString().isNotEmpty) pw.Text('Ship To: ${r['shipTo']}'),
      pw.SizedBox(height: 16),
      pw.Table.fromTextArray(headers: ['Description', 'Qty', 'Rate (INR)', 'Total (INR)'],
        data: items.map((i) => [i['description'].toString(), i['quantity'].toString(), (i['rate'] as num).toStringAsFixed(2), (i['total'] as num).toStringAsFixed(2)]).toList()),
      pw.SizedBox(height: 12),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Grand Total: Rs. ${(r['amount'] as num).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
      if (['Invoice','Tax Invoice'].contains(r['type'])) pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Received: Rs. ${received.toStringAsFixed(2)}    Balance Due: Rs. ${((r['amount'] as num).toDouble()-received).clamp(0.0,(r['amount'] as num).toDouble()).toStringAsFixed(2)}')),
      if (r['type'] == 'Tax Invoice' && (business['bankName'] ?? '').toString().isNotEmpty) pw.Text('Bank: ${business['bankName']}  Account: ${business['accountName'] ?? ''}  A/C: ${business['accountNumber'] ?? ''}  IFSC: ${business['ifsc'] ?? ''}'),
      if ((r['notes'] ?? '').toString().isNotEmpty) pw.Text('Notes: ${r['notes']}'),
      pw.Spacer(), pw.Center(child: pw.Text('Thank you')),
    ]));
    await Printing.sharePdf(bytes: await pdf.save(), filename: '${r['number']}.pdf');
  }

  Future<void> reports() async {
    String category = 'All Categories';
    String period = 'Daily';
    DateTime start = DateTime.now(), end = DateTime.now();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: const Text('Category Reports'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category'),
          items: ['All Categories', ...categories, 'Items / Stock'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) { if (v != null) refresh(() => category = v); }),
        DropdownButtonFormField<String>(value: period, decoration: const InputDecoration(labelText: 'Period'),
          items: ['Daily', 'Monthly', 'Date Range'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) { if (v != null) refresh(() => period = v); }),
        if (period == 'Date Range') ...[
          TextButton(onPressed: () async { final d = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) refresh(() => start = d); }, child: Text('From: ${start.toString().substring(0, 10)}')),
          TextButton(onPressed: () async { final d = await showDatePicker(context: ctx, initialDate: end, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) refresh(() => end = d); }, child: Text('To: ${end.toString().substring(0, 10)}')),
        ],
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate'))],
    )));
    if (ok != true || !mounted) return;
    if (period == 'Daily') { final d = DateTime.now(); start = DateTime(d.year, d.month, d.day); end = start.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)); }
    else if (period == 'Monthly') { final d = DateTime.now(); start = DateTime(d.year, d.month, 1); end = DateTime(d.year, d.month + 1, 1).subtract(const Duration(microseconds: 1)); }
    else { if (end.isBefore(start)) { final t = start; start = end; end = t; } end = DateTime(end.year, end.month, end.day, 23, 59, 59); }
    final filtered = records.where((r) {
      final d = DateTime.tryParse((r['date'] ?? '').toString());
      return d != null && !d.isBefore(start) && !d.isAfter(end) && (category == 'All Categories' || r['type'] == category);
    }).toList();
    final income = filtered.where((r) => r['type'] == 'Income').fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
    final expense = filtered.where((r) => r['type'] == 'Expense').fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
    final selectedTotal = filtered.fold<double>(0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(build: (ctx) => [
      pw.Text('$category — $period Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.Text('From: ${start.toString().substring(0, 10)}  To: ${end.toString().substring(0, 10)}'),
      pw.SizedBox(height: 10),
      pw.Text('Selected total: Rs. ${selectedTotal.toStringAsFixed(2)}'),
      pw.Text('Income: Rs. ${income.toStringAsFixed(2)}    Expense: Rs. ${expense.toStringAsFixed(2)}    Balance: Rs. ${(income-expense).toStringAsFixed(2)}'),
      pw.SizedBox(height: 12),
      pw.Table.fromTextArray(headers: ['Category', 'Number', 'Customer', 'Amount (INR)'], data: filtered.map((r) => [r['type'].toString(), r['number'].toString(), r['customer'].toString(), (r['amount'] as num).toStringAsFixed(2)]).toList()),
    ]));
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('$category — $period Report'),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('From ${start.toString().substring(0, 10)} to ${end.toString().substring(0, 10)}'),
        Text('Selected total: ${money(selectedTotal)}'),
        Text('Income: ${money(income)}    Expense: ${money(expense)}'),
        Text('Balance: ${money(income-expense)}'),
        const Divider(),
        ...filtered.map((r) => ListTile(dense: true, title: Text('${r['number']} • ${r['customer']}'), subtitle: Text('${r['type']} • ${(r['date'] ?? '').toString().substring(0, 10)}'), trailing: Text(money(r['amount'])))),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton.icon(onPressed: () async { await Printing.sharePdf(bytes: await pdf.save(), filename: 'PR_Business_Report.pdf'); }, icon: const Icon(Icons.picture_as_pdf), label: const Text('Share PDF')),
      ],
    ));
  }

  Future<void> stockReport() async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(build: (ctx) => [
      pw.Text('Items / Stock Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.Table.fromTextArray(headers: ['Code', 'Item', 'Category', 'Qty', 'Purchase', 'Selling'],
        data: stock.map((s) => [s['code'].toString(), s['name'].toString(), s['category'].toString(), s['quantity'].toString(), (s['purchaseRate'] as num).toStringAsFixed(2), (s['sellingRate'] as num).toStringAsFixed(2)]).toList()),
    ]));
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Items / Stock Report'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: stock.map((s) => ListTile(
        title: Text('${s['name']} ${((s['quantity'] as num) <= (s['minimum'] as num)) ? '• LOW STOCK' : ''}'),
        subtitle: Text('${s['code']} • ${s['category']} • Purchase ${money(s['purchaseRate'])} • Selling ${money(s['sellingRate'])}'),
        trailing: Text('${s['quantity']} ${s['unit']}'),
      )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')), FilledButton(onPressed: () async { await Printing.sharePdf(bytes: await pdf.save(), filename: 'PR_Business_Stock_Report.pdf'); }, child: const Text('Share PDF'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isStock = selectedTab == categories.length;
    final type = isStock ? 'Items / Stock' : categories[selectedTab];
    final visible = isStock ? <Map<String, dynamic>>[] : records.where((r) => r['type'] == type).toList()..sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
    final total = visible.fold<double>(0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('PR BUSINESS'), actions: [
        IconButton(tooltip: 'Business Profiles', onPressed: businessSettings, icon: const Icon(Icons.business)),
        IconButton(tooltip: 'Staff Management', onPressed: manageStaff, icon: const Icon(Icons.groups_outlined)),
        IconButton(tooltip: 'Category reports', onPressed: reports, icon: const Icon(Icons.analytics_outlined)),
        if (isStock) IconButton(tooltip: 'Stock report', onPressed: stockReport, icon: const Icon(Icons.picture_as_pdf)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isStock ? () => showStockDialog() : addRecord,
        icon: const Icon(Icons.add), label: Text(isStock ? 'Add Stock Item' : 'Add $type'),
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), child: Row(children: [
          ...List<Widget>.generate(categories.length, (index) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(categories[index]),
                  selected: selectedTab == index,
                  onSelected: (_) => setState(() => selectedTab = index),
                ),
              )),
          ChoiceChip(label: const Text('Items / Stock'), selected: isStock, onSelected: (_) => setState(() => selectedTab = categories.length)),
        ])),
        if (!isStock) Card(margin: const EdgeInsets.all(12), child: ListTile(leading: const Icon(Icons.account_balance_wallet), title: Text('$type Total'), trailing: Text(money(total), style: const TextStyle(fontWeight: FontWeight.bold)))),
        Expanded(child: isStock
          ? stock.isEmpty ? const Center(child: Text('No stock items yet. Tap Add Stock Item.')) : ListView.builder(itemCount: stock.length, itemBuilder: (ctx, i) {
              final s = stock[i];
              final low = (s['quantity'] as num) <= (s['minimum'] as num);
              return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), child: ListTile(
                leading: Icon(low ? Icons.warning_amber : Icons.inventory_2_outlined, color: low ? Colors.orange : null),
                title: Text('${s['name']} ${low ? '• LOW STOCK' : ''}'),
                subtitle: Text('${s['code']} • ${s['category']} • Qty ${s['quantity']} ${s['unit']}\nPurchase ${money(s['purchaseRate'])} • Selling ${money(s['sellingRate'])}'),
                isThreeLine: true,
                trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => showStockDialog(item: s)),
              ));
            })
          : visible.isEmpty ? Center(child: Text('No $type records yet.')) : ListView.builder(itemCount: visible.length, itemBuilder: (ctx, i) {
              final r = visible[i];
              return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(r['customer'].toString()),
                subtitle: Text('${r['number']} • ${(r['date'] ?? '').toString().substring(0, 10)}\n${r['description'] ?? ''}${r['type']=='Invoice' ? '\nReceived ${money(r['receivedAmount'] ?? 0)} • Due ${money(((r['amount'] as num?)?.toDouble() ?? 0)-((r['receivedAmount'] as num?)?.toDouble() ?? 0))}' : ''}'),
                isThreeLine: true,
                trailing: Text(money(r['amount'])),
                onTap: () async {
                  final action = await showModalBottomSheet<String>(context: context, builder: (sc) => SafeArea(child: Wrap(children: [
                    ListTile(leading: const Icon(Icons.edit), title: const Text('Edit'), onTap: () => Navigator.pop(sc, 'edit')),
                    if (['Invoice','Tax Invoice'].contains(r['type'])) ListTile(leading: const Icon(Icons.payments_outlined), title: const Text('Record Payment'), subtitle: Text('Outstanding: ${money(((r['amount'] as num?)?.toDouble() ?? 0) - ((r['receivedAmount'] as num?)?.toDouble() ?? 0))}'), onTap: () => Navigator.pop(sc, 'payment')),
                    ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('Preview'), onTap: () => Navigator.pop(sc, 'preview')),
                    ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('Share PDF'), onTap: () => Navigator.pop(sc, 'pdf')),
                    ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete'), onTap: () => Navigator.pop(sc, 'delete')),
                  ])));
                  if (!mounted) return;
                  if (action == 'edit') await editRecord(r);
                  if (action == 'pdf') await createPdf(r);
                  if (action == 'payment') await recordPayment(r);
                  if (action == 'preview') await showDocumentPreview(r);
                  if (action == 'delete') await deleteRecord(r);
                },
              ));
            })),
      ]),
    );
  }
}
