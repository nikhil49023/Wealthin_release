import 'package:flutter/material.dart';
import '../../core/services/financial_calculator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/wealthin_theme.dart';

class FinancialToolsScreen extends StatelessWidget {
  const FinancialToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Financial Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ToolCard(
            title: 'Savings Rate Calculator',
            icon: Icons.savings_outlined,
            color: AppTheme.emerald,
            onTap: () => _showSavingsRateCalculator(context),
          ),
          _ToolCard(
            title: 'Compound Interest',
            icon: Icons.trending_up,
            color: WealthInTheme.purpleLight,
            onTap: () => _showCompoundInterestCalculator(context),
          ),
          _ToolCard(
            title: 'Emergency Fund Check',
            icon: Icons.health_and_safety_outlined,
            color: WealthInTheme.coral,
            onTap: () => _showEmergencyFundCalculator(context),
          ),
          _ToolCard(
            title: 'Per Capita Income',
            icon: Icons.people_outline,
            color: WealthInTheme.gold,
            onTap: () => _showPerCapitaCalculator(context),
          ),
        ],
      ),
    );
  }

  void _showSavingsRateCalculator(BuildContext context) {
    final incomeCtrl = TextEditingController();
    final expenseCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Savings Rate', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: incomeCtrl,
              decoration: const InputDecoration(labelText: 'Monthly Income', prefixText: '₹'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: expenseCtrl,
              decoration: const InputDecoration(labelText: 'Monthly Expenses', prefixText: '₹'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final income = double.tryParse(incomeCtrl.text) ?? 0;
                final expense = double.tryParse(expenseCtrl.text) ?? 0;
                final rate = FinancialCalculator.calculateSavingsRate(income, expense);
                Navigator.pop(ctx);
                _showResult(context, 'Savings Rate: $rate%');
              },
              child: const Text('Calculate'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompoundInterestCalculator(BuildContext context) {
    final principalCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final yearsCtrl = TextEditingController();
    final monthlyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Compound Interest', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: principalCtrl,
              decoration: const InputDecoration(labelText: 'Principal Amount', prefixText: '₹'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: rateCtrl,
              decoration: const InputDecoration(labelText: 'Annual Rate (%)'),
              keyboardType: TextInputType.number,
            ),
             const SizedBox(height: 8),
            TextField(
              controller: yearsCtrl,
              decoration: const InputDecoration(labelText: 'Duration (Years)'),
              keyboardType: TextInputType.number,
            ),
             const SizedBox(height: 8),
            TextField(
              controller: monthlyCtrl,
              decoration: const InputDecoration(labelText: 'Monthly Contribution (Optional)', prefixText: '₹'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final principal = double.tryParse(principalCtrl.text) ?? 0;
                final rate = double.tryParse(rateCtrl.text) ?? 0;
                final years = int.tryParse(yearsCtrl.text) ?? 0;
                final monthly = double.tryParse(monthlyCtrl.text) ?? 0;

                final result = FinancialCalculator.calculateCompoundInterest(
                  principal: principal,
                  rate: rate,
                  years: years,
                  monthlyContribution: monthly,
                );
                Navigator.pop(ctx);
                _showResult(context, 'Total Amount: ₹${result['total_amount']}\nInterest Earned: ₹${result['interest_earned']}');
              },
              child: const Text('Calculate'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyFundCalculator(BuildContext context) {
    final savingsCtrl = TextEditingController();
    final expenseCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Emergency Fund Check', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: savingsCtrl,
              decoration: const InputDecoration(labelText: 'Current Savings', prefixText: '₹'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: expenseCtrl,
              decoration: const InputDecoration(labelText: 'Monthly Expenses', prefixText: '₹'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final savings = double.tryParse(savingsCtrl.text) ?? 0;
                final expenses = double.tryParse(expenseCtrl.text) ?? 0;
                
                final result = FinancialCalculator.calculateEmergencyFundStatus(
                  currentSavings: savings, 
                  monthlyExpenses: expenses
                );
                Navigator.pop(ctx);
                _showResult(context, 'Health: ${result['health_status']}\nMonths Covered: ${result['months_covered']}');
              },
              child: const Text('Check Status'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPerCapitaCalculator(BuildContext context) {
     final incomeCtrl = TextEditingController();
    final familySizeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Per Capita Income', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: incomeCtrl,
              decoration: const InputDecoration(labelText: 'Total Monthly Income', prefixText: '₹'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: familySizeCtrl,
              decoration: const InputDecoration(labelText: 'Family Size'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final income = double.tryParse(incomeCtrl.text) ?? 0;
                final size = int.tryParse(familySizeCtrl.text) ?? 1;
                final result = FinancialCalculator.calculatePerCapitaIncome(income, size);
                Navigator.pop(ctx);
                _showResult(context, 'Per Capita Income: ₹$result');
              },
              child: const Text('Calculate'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResult(BuildContext context, String message) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text('Result'),
        content: Text(message, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      )
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: WealthInTheme.gray500),
            ],
          ),
        ),
      ),
    );
  }
}

