# Flutter Frontend Integration Guide - P0 Features

This guide shows how to integrate the new P0 features into the WealthIn Flutter app.

## 📦 Prerequisites

Add these dependencies to `pubspec.yaml` (if not already present):

```yaml
dependencies:
  http: ^1.1.0
  image_picker: ^1.0.4  # For bill photo capture
  fl_chart: ^0.65.0     # For forecast visualizations
  url_launcher: ^6.2.1  # For UPI deep links
```

---

## 1️⃣ Bill Splitting Integration

### Step 1: Create Data Models

Create `lib/core/models/bill_split_models.dart`:

```dart
class BillSplit {
  final int id;
  final double totalAmount;
  final String splitMethod;
  final int? groupId;
  final String description;
  final String createdAt;
  final List<SplitShare> shares;

  BillSplit({
    required this.id,
    required this.totalAmount,
    required this.splitMethod,
    this.groupId,
    required this.description,
    required this.createdAt,
    required this.shares,
  });

  factory BillSplit.fromJson(Map<String, dynamic> json) {
    return BillSplit(
      id: json['id'],
      totalAmount: json['total_amount'].toDouble(),
      splitMethod: json['split_method'],
      groupId: json['group_id'],
      description: json['description'] ?? '',
      createdAt: json['created_at'],
      shares: (json['items'] as List?)
              ?.map((item) => SplitShare.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class SplitShare {
  final String userId;
  final String participantName;
  final double amount;
  final bool settled;

  SplitShare({
    required this.userId,
    required this.participantName,
    required this.amount,
    required this.settled,
  });

factory SplitShare.fromJson(Map<String, dynamic> json) {
    return SplitShare(
      userId: json['participant_id'],
      participantName: json['participant_name'] ?? json['participant_id'],
      amount: json['amount'].toDouble(),
      settled: json['settled'] == 1,
    );
  }
}

class DebtSummary {
  final List<Debt> owesMe;
  final List<Debt> iOwe;
  final double totalOwedToMe;
  final double totalIOwe;
  final double netBalance;
  final List<Settlement> settlements;

  DebtSummary({
    required this.owesMe,
    required this.iOwe,
    required this.totalOwedToMe,
    required this.totalIOwe,
    required this.netBalance,
    required this.settlements,
  });

  factory DebtSummary.fromJson(Map<String, dynamic> json) {
    return DebtSummary(
      owesMe: (json['owes_me'] as List)
          .map((d) => Debt.fromJson(d))
          .toList(),
      iOwe: (json['i_owe'] as List)
          .map((d) => Debt.fromJson(d))
          .toList(),
      totalOwedToMe: json['total_owed_to_me'].toDouble(),
      totalIOwe: json['total_i_owe'].toDouble(),
      netBalance: json['net_balance'].toDouble(),
      settlements: (json['settlements'] as List)
          .map((s) => Settlement.fromJson(s))
          .toList(),
    );
  }
}

class Debt {
  final String userId;
  final double amount;

  Debt({
    required this.userId,
    required this.amount,
  });

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      userId: json['user_id'],
      amount: json['amount'].toDouble(),
    );
  }
}

class Settlement {
  final String fromUser;
  final String toUser;
  final double amount;

  Settlement({
    required this.fromUser,
    required this.toUser,
    required this.amount,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      fromUser: json['from_user'],
      toUser: json['to_user'],
      amount: json['amount'].toDouble(),
    );
  }
}
```

### Step 2: Update DataService

Add to `lib/core/services/data_service.dart`:

```dart
// Bill Splitting Methods

Future<Map<String, dynamic>> createBillSplit({
  required double totalAmount,
  required String splitMethod,
  required List<Map<String, dynamic>> participants,
  required String createdBy,
  int? groupId,
  String? description,
  String? imageUrl,
}) async {
  final response = await http.post(
    Uri.parse('$_baseUrl/bill-split/create'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'total_amount': totalAmount,
      'split_method': splitMethod,
      'participants': participants,
      'created_by': createdBy,
      'group_id': groupId,
      'description': description,
      'image_url': imageUrl,
    }),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to create bill split');
  }
}

Future<BillSplit> getBillSplit(int splitId) async {
  final response = await http.get(
    Uri.parse('$_baseUrl/bill-split/$splitId'),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return BillSplit.fromJson(data['split']);
  } else {
    throw Exception('Failed to get bill split');
  }
}

Future<DebtSummary> getUserDebts(String userId, {int? groupId}) async {
  var url = '$_baseUrl/bill-split/debts/$userId';
  if (groupId != null) {
    url += '?group_id=$groupId';
  }

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return DebtSummary.fromJson(data);
  } else {
    throw Exception('Failed to get user debts');
  }
}

Future<bool> settleDebt({
  required String fromUserId,
  required String toUserId,
  required double amount,
  int? groupId,
}) async {
  final response = await http.post(
    Uri.parse('$_baseUrl/bill-split/settle'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'amount': amount,
      'group_id': groupId,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['success'] == true;
  } else {
    throw Exception('Failed to settle debt');
  }
}

// UPI Payment Helper
Future<void> payViaUPI({
  required String receiverUPI,
  required String receiverName,
  required double amount,
}) async {
  final upiUrl =
      'upi://pay?pa=$receiverUPI&pn=$receiverName&am=$amount&cu=INR';

  if (await canLaunchUrl(Uri.parse(upiUrl))) {
    await launchUrl(Uri.parse(upiUrl), mode: LaunchMode.externalApplication);
  } else {
    throw Exception('Could not launch UPI app');
  }
}
```

### Step 3: Create Bill Split Screen

Create `lib/features/bill_split/bill_split_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class BillSplitScreen extends StatefulWidget {
  const BillSplitScreen({Key? key}) : super(key: key);

  @override
  State<BillSplitScreen> createState() => _BillSplitScreenState();
}

class _BillSplitScreenState extends State<BillSplitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _splitMethod = 'equal';
  List<Map<String, dynamic>> _participants = [];
  XFile? _billImage;

  final ImagePicker _picker = ImagePicker();

  Future<void> _captureImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _billImage = image;
      });

      // TODO: Send image to OCR endpoint for automatic extraction
    }
  }

  void _addParticipant() {
    setState(() {
      _participants.add({
        'user_id': 'user${_participants.length + 1}',
        'name': '',
      });
    });
  }

  Future<void> _createSplit() async {
    if (_formKey.currentState!.validate()) {
      try {
        final result = await dataService.createBillSplit(
          totalAmount: double.parse(_amountController.text),
          splitMethod: _splitMethod,
          participants: _participants,
          createdBy: currentUserId,
          description: _descriptionController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bill split created successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Bill'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _captureImage,
            tooltip: 'Scan Bill',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Amount Input
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Total Amount',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Split Method Selector
            DropdownButtonFormField<String>(
              value: _splitMethod,
              decoration: const InputDecoration(
                labelText: 'Split Method',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'equal', child: Text('Equal Split')),
                DropdownMenuItem(value: 'custom', child: Text('Custom Amounts')),
                DropdownMenuItem(value: 'percentage', child: Text('By Percentage')),
                DropdownMenuItem(value: 'by_item', child: Text('By Item')),
              ],
              onChanged: (value) {
                setState(() {
                  _splitMethod = value!;
                });
              },
            ),

            const SizedBox(height: 24),

            // Participants Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Participants (${_participants.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ElevatedButton.icon(
                  onPressed: _addParticipant,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Participants List
            ..._participants.asMap().entries.map((entry) {
              final index = entry.key;
              final participant = entry.value;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'Name',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      _participants[index]['name'] = value;
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _participants.removeAt(index);
                      });
                    },
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 24),

            // Create Button
            ElevatedButton(
              onPressed: _createSplit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: const Text('Create Split'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 4: Create Debt Ledger Screen

Create `lib/features/bill_split/debt_ledger_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DebtLedgerScreen extends StatefulWidget {
  const DebtLedgerScreen({Key? key}) : super(key: key);

  @override
  State<DebtLedgerScreen> createState() => _DebtLedgerScreenState();
}

class _DebtLedgerScreenState extends State<DebtLedgerScreen> {
  DebtSummary? _debtSummary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    try {
      final summary = await dataService.getUserDebts(currentUserId);
      setState(() {
        _debtSummary = summary;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading debts: $e')),
        );
      }
    }
  }

  Future<void> _settleDebt(String otherUserId, double amount) async {
    try {
      await dataService.settleDebt(
        fromUserId: currentUserId,
        toUserId: otherUserId,
        amount: amount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debt settled!')),
        );
        _loadDebts(); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildNetBalanceCard() {
    if (_debtSummary == null) return const SizedBox();

    final netBalance = _debtSummary!.netBalance;
    final isPositive = netBalance >= 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Net Balance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '₹${netBalance.abs().toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              isPositive ? 'People owe you' : 'You owe',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDebts,
          ),
        ],
      ),
      body: _debtSummary == null
          ? const Center(child: Text('No debts found'))
          : ListView(
              children: [
                _buildNetBalanceCard(),

                // People Who Owe Me
                if (_debtSummary!.owesMe.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Owes Me',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ..._debtSummary!.owesMe.map((debt) {
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(debt.userId),
                        subtitle: Text('Owes you ₹${debt.amount.toStringAsFixed(0)}'),
                        trailing: TextButton(
                          onPressed: () {
                            // Show UPI request or mark as settled
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Collect Payment'),
                                content: Text(
                                  'Request ₹${debt.amount.toStringAsFixed(0)} from ${debt.userId}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      // TODO: Request payment via UPI
                                      await _settleDebt(debt.userId, debt.amount);
                                    },
                                    child: const Text('Mark Settled'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('Collect'),
                        ),
                      ),
                    );
                  }).toList(),
                ],

                // People I Owe
                if (_debtSummary!.iOwe.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'I Owe',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ..._debtSummary!.iOwe.map((debt) {
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(debt.userId),
                        subtitle: Text('You owe ₹${debt.amount.toStringAsFixed(0)}'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            // Launch UPI payment
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Pay via UPI'),
                                content: Text(
                                  'Pay ₹${debt.amount.toStringAsFixed(0)} to ${debt.userId}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      // TODO: Get actual UPI ID
                                      await dataService.payViaUPI(
                                        receiverUPI: '${debt.userId}@upi',
                                        receiverName: debt.userId,
                                        amount: debt.amount,
                                      );
                                    },
                                    child: const Text('Pay Now'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('Pay'),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BillSplitScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Split'),
      ),
    );
  }
}
```

---

## 2️⃣ Expense Forecasting Integration

### Step 1: Create Forecast Models

Add to `lib/core/models/forecast_models.dart`:

```dart
class MonthEndForecast {
  final double projectedTotal;
  final double currentSpending;
  final int daysElapsed;
  final int daysRemaining;
  final double dailyAverage;
  final double budgetLimit;
  final double overBudgetBy;
  final double confidenceLevel;
  final String recommendation;
  final String category;

  MonthEndForecast({
    required this.projectedTotal,
    required this.currentSpending,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.dailyAverage,
    required this.budgetLimit,
    required this.overBudgetBy,
    required this.confidenceLevel,
    required this.recommendation,
    required this.category,
  });

  factory MonthEndForecast.fromJson(Map<String, dynamic> json) {
    return MonthEndForecast(
      projectedTotal: json['projected_total'].toDouble(),
      currentSpending: json['current_spending'].toDouble(),
      daysElapsed: json['days_elapsed'],
      daysRemaining: json['days_remaining'],
      dailyAverage: json['daily_average'].toDouble(),
      budgetLimit: json['budget_limit'].toDouble(),
      overBudgetBy: json['over_budget_by'].toDouble(),
      confidenceLevel: json['confidence_level'].toDouble(),
      recommendation: json['recommendation'],
      category: json['category'],
    );
  }

  // Helper to get status color
  Color getStatusColor() {
    if (budgetLimit == 0) return Colors.grey;
    final percentUsed = projectedTotal / budgetLimit;
    if (percentUsed > 1.0) return Colors.red;
    if (percentUsed > 0.9) return Colors.orange;
    return Colors.green;
  }

  // Helper to get status icon
  IconData getStatusIcon() {
    if (budgetLimit == 0) return Icons.info;
    final percentUsed = projectedTotal / budgetLimit;
    if (percentUsed > 1.0) return Icons.warning;
    if (percentUsed > 0.9) return Icons.trending_up;
    return Icons.check_circle;
  }
}

class WeeklyDigest {
  final double weekTotal;
  final double previousWeekTotal;
  final double changePercent;
  final List<TopCategory> topCategories;
  final List<String> insights;

  WeeklyDigest({
    required this.weekTotal,
    required this.previousWeekTotal,
    required this.changePercent,
    required this.topCategories,
    required this.insights,
  });

  factory WeeklyDigest.fromJson(Map<String, dynamic> json) {
    return WeeklyDigest(
      weekTotal: json['week_total'].toDouble(),
      previousWeekTotal: json['previous_week_total'].toDouble(),
      changePercent: json['change_percent'].toDouble(),
      topCategories: (json['top_categories'] as List)
          .map((c) => TopCategory.fromJson(c))
          .toList(),
      insights: List<String>.from(json['insights']),
    );
  }
}

class TopCategory {
  final String category;
  final double amount;
  final double percentOfTotal;

  TopCategory({
    required this.category,
    required this.amount,
    required this.percentOfTotal,
  });

  factory TopCategory.fromJson(Map<String, dynamic> json) {
    return TopCategory(
      category: json['category'],
      amount: json['amount'].toDouble(),
      percentOfTotal: json['percent_of_total'].toDouble(),
    );
  }
}
```

### Step 2: Add Forecast Methods to DataService

Add to `lib/core/services/data_service.dart`:

```dart
// Forecasting Methods

Future<MonthEndForecast> getMonthEndForecast(
  String userId, {
  String? category,
}) async {
  var url = '$_baseUrl/forecast/month-end/$userId';
  if (category != null) {
    url += '?category=$category';
  }

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return MonthEndForecast.fromJson(data);
  } else {
    throw Exception('Failed to get forecast');
  }
}

Future<WeeklyDigest> getWeeklyDigest(String userId) async {
  final response = await http.get(
    Uri.parse('$_baseUrl/forecast/weekly-digest/$userId'),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response body);
    return WeeklyDigest.fromJson(data);
  } else {
    throw Exception('Failed to get weekly digest');
  }
}
```

### Step 3: Create Forecast Widget

Create `lib/widgets/forecast_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ForecastCard extends StatelessWidget {
  final MonthEndForecast forecast;

  const ForecastCard({
    Key? key,
    required this.forecast,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentUsed = forecast.budgetLimit > 0
        ? forecast.projectedTotal / forecast.budgetLimit
        : 0.0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  forecast.getStatusIcon(),
                  color: forecast.getStatusColor(),
                ),
                const SizedBox(width: 8),
                Text(
                  'Month-End Forecast',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Gauge Chart
            SizedBox(
              height: 120,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: forecast.currentSpending,
                      color: Colors.blue,
                      title: 'Spent',
                      radius: 40,
                    ),
                    PieChartSectionData(
                      value: forecast.projectedTotal - forecast.currentSpending,
                      color: forecast.getStatusColor(),
                      title: 'Projected',
                      radius: 40,
                    ),
                    if (forecast.budgetLimit > forecast.projectedTotal)
                      PieChartSectionData(
                        value: forecast.budgetLimit - forecast.projectedTotal,
                        color: Colors.grey.shade300,
                        title: 'Budget Left',
                        radius: 40,
                      ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  'Current',
                  '₹${forecast.currentSpending.toStringAsFixed(0)}',
                  Colors.blue,
                ),
                _buildStat(
                  'Projected',
                  '₹${forecast.projectedTotal.toStringAsFixed(0)}',
                  forecast.getStatusColor(),
                ),
                _buildStat(
                  'Budget',
                  '₹${forecast.budgetLimit.toStringAsFixed(0)}',
                  Colors.grey,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Recommendation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: forecast.getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    forecast.getStatusIcon(),
                    color: forecast.getStatusColor(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      forecast.recommendation,
                      style: TextStyle(
                        color: forecast.getStatusColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Days Remaining
            LinearProgressIndicator(
              value: forecast.daysElapsed /
                  (forecast.daysElapsed + forecast.daysRemaining),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(forecast.getStatusColor()),
            ),
            const SizedBox(height: 4),
            Text(
              '${forecast.daysRemaining} days remaining',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
```

### Step 4: Add to Dashboard

In your main dashboard screen:

```dart
// Add this to the dashboard body
FutureBuilder<MonthEndForecast>(
  future: dataService.getMonthEndForecast(currentUserId),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return ForecastCard(forecast: snapshot.data!);
    } else if (snapshot.hasError) {
      return const SizedBox();
    }
    return const CircularProgressIndicator();
  },
),
```

---

## 🚀 Quick Start Checklist

- [ ] Copy model classes to your project
- [ ] Add DataService methods
- [ ] Create bill split screen
- [ ] Create debt ledger screen
- [ ] Add forecast widgets
- [ ] Test with backend API
- [ ] Add navigation menu items
- [ ] Implement UPI deep linking
- [ ] Add push notifications for forecasts

---

## 🔔 Push Notifications (Future Enhancement)

To add notifications for budget alerts and weekly digests, use `flutter_local_notifications`:

```dart
// Show budget warning
void showBudgetWarning(MonthEndForecast forecast) {
  if (forecast.overBudgetBy > 0) {
    LocalNotifications.show(
      title: '⚠️ Budget Alert',
      body: forecast.recommendation,
      payload: 'budget_alert',
    );
  }
}

// Send weekly digest on Sunday mornings
void scheduleWeeklyDigest() {
  LocalNotifications.scheduledWeekly(
    Time(9, 0, 0), // 9 AM
    DateTime.sunday,
    title: ' Your Weekly Spending Summary',
    body: 'Tap to view insights',
  );
}
```

---

## 📱 UPI Deep Link Generation

```dart
String generateUPILink({
  required String receiverUPI,
  required String receiverName,
  required double amount,
  String? note,
}) {
  final params = {
    'pa': receiverUPI,
    'pn': receiverName,
    'am': amount.toStringAsFixed(2),
    'cu': 'INR',
    if (note != null) 'tn': note,
  };

  final queryString = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
      .join('&');

  return 'upi://pay?$queryString';
}
```

---

## 🎨 Theme Integration

Use your existing color scheme:

```dart
// Primary colors
const primaryGold = Color(0xFFD4AF37);
const navyBlue = Color(0xFF1A237E);

// In ForecastCard:
color: percentUsed > 1.0 
    ? Colors.red.shade800 
    : percentUsed > 0.9 
        ? Colors.orange.shade700 
        : primaryGold,
```

---

## ✅ Testing

Test these scenarios:

1. **Bill Splitting**:
   - Create equal split with 3 people
   - Create custom split with different amounts
   - View debt ledger
   - Mark debt as settled
   - Launch UPI payment

2. **Forecasting**:
   - View forecast with zero transactions
   - View forecast mid-month
   - Check budget alerts
   - View weekly digest

---

**Need Help?** Check the backend test at `backend/test_p0_features.py` for working examples of the API calls.
