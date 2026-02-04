import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/wealthin_theme.dart';

/// Investment Calculator Screen
/// Provides SIP, FD, EMI, RD calculators with visual results
class InvestmentCalculatorScreen extends StatefulWidget {
  const InvestmentCalculatorScreen({super.key});

  @override
  State<InvestmentCalculatorScreen> createState() =>
      _InvestmentCalculatorScreenState();
}

class _InvestmentCalculatorScreenState extends State<InvestmentCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // SIP Controllers
  final _sipAmountController = TextEditingController(text: '5000');
  final _sipRateController = TextEditingController(text: '12');
  final _sipYearsController = TextEditingController(text: '10');

  // FD Controllers
  final _fdPrincipalController = TextEditingController(text: '100000');
  final _fdRateController = TextEditingController(text: '7');
  final _fdYearsController = TextEditingController(text: '5');

  // EMI Controllers
  final _emiPrincipalController = TextEditingController(text: '1000000');
  final _emiRateController = TextEditingController(text: '8.5');
  final _emiYearsController = TextEditingController(text: '20');

  // RD Controllers
  final _rdAmountController = TextEditingController(text: '5000');
  final _rdRateController = TextEditingController(text: '6.5');
  final _rdYearsController = TextEditingController(text: '5');

  Map<String, dynamic>? _sipResult;
  Map<String, dynamic>? _fdResult;
  Map<String, dynamic>? _emiResult;
  Map<String, dynamic>? _rdResult;

  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sipAmountController.dispose();
    _sipRateController.dispose();
    _sipYearsController.dispose();
    _fdPrincipalController.dispose();
    _fdRateController.dispose();
    _fdYearsController.dispose();
    _emiPrincipalController.dispose();
    _emiRateController.dispose();
    _emiYearsController.dispose();
    _rdAmountController.dispose();
    _rdRateController.dispose();
    _rdYearsController.dispose();
    super.dispose();
  }

  Future<void> _calculateSIP() async {
    setState(() => _isCalculating = true);
    try {
      final monthlyInvestment =
          double.tryParse(_sipAmountController.text) ?? 5000;
      final expectedRate = double.tryParse(_sipRateController.text) ?? 12;
      final durationMonths =
          (int.tryParse(_sipYearsController.text) ?? 10) * 12;

      final monthlyRate = expectedRate / 12 / 100;
      double futureValue;
      if (monthlyRate == 0) {
        futureValue = monthlyInvestment * durationMonths;
      } else {
        futureValue =
            monthlyInvestment *
            ((math.pow(1 + monthlyRate, durationMonths) - 1) / monthlyRate) *
            (1 + monthlyRate);
      }

      final totalInvested = monthlyInvestment * durationMonths;
      final wealthGained = futureValue - totalInvested;

      setState(
        () => _sipResult = {
          'total_invested': totalInvested.round(),
          'future_value': futureValue.round(),
          'wealth_gained': wealthGained.round(),
          'returns_percentage': totalInvested > 0
              ? ((wealthGained / totalInvested) * 100).round()
              : 0,
        },
      );
    } catch (e) {
      _showError('SIP calculation failed');
    }
    setState(() => _isCalculating = false);
  }

  Future<void> _calculateFD() async {
    setState(() => _isCalculating = true);
    try {
      final principal = double.tryParse(_fdPrincipalController.text) ?? 100000;
      final rate = double.tryParse(_fdRateController.text) ?? 7;
      final tenureMonths = (int.tryParse(_fdYearsController.text) ?? 5) * 12;

      const n = 4; // quarterly compounding
      final r = rate / 100;
      final t = tenureMonths / 12;

      final maturityAmount = principal * math.pow(1 + r / n, n * t);
      final interestEarned = maturityAmount - principal;
      final effectiveRate = (math.pow(1 + r / n, n.toDouble()) - 1) * 100;

      setState(
        () => _fdResult = {
          'principal': principal,
          'maturity_amount': maturityAmount.round(),
          'interest_earned': interestEarned.round(),
          'effective_annual_rate': effectiveRate.round(),
        },
      );
    } catch (e) {
      _showError('FD calculation failed');
    }
    setState(() => _isCalculating = false);
  }

  Future<void> _calculateEMI() async {
    setState(() => _isCalculating = true);
    try {
      final principal =
          double.tryParse(_emiPrincipalController.text) ?? 1000000;
      final rate = double.tryParse(_emiRateController.text) ?? 8.5;
      final tenureMonths = (int.tryParse(_emiYearsController.text) ?? 20) * 12;

      final monthlyRate = rate / 12 / 100;
      double emi;
      if (monthlyRate == 0) {
        emi = principal / tenureMonths;
      } else {
        emi =
            principal *
            monthlyRate *
            math.pow(1 + monthlyRate, tenureMonths.toDouble()) /
            (math.pow(1 + monthlyRate, tenureMonths.toDouble()) - 1);
      }

      final totalPayment = emi * tenureMonths;
      final totalInterest = totalPayment - principal;

      setState(
        () => _emiResult = {
          'principal': principal,
          'emi': emi.round(),
          'total_payment': totalPayment.round(),
          'total_interest': totalInterest.round(),
        },
      );
    } catch (e) {
      _showError('EMI calculation failed');
    }
    setState(() => _isCalculating = false);
  }

  Future<void> _calculateRD() async {
    setState(() => _isCalculating = true);
    try {
      final monthlyDeposit = double.tryParse(_rdAmountController.text) ?? 5000;
      final rate = double.tryParse(_rdRateController.text) ?? 6.5;
      final tenureMonths = (int.tryParse(_rdYearsController.text) ?? 5) * 12;

      final quarterlyRate = rate / 4 / 100;
      double maturityAmount = 0;

      for (int month = 0; month < tenureMonths; month++) {
        final remainingQuarters = (tenureMonths - month) / 3;
        final amount =
            monthlyDeposit * math.pow(1 + quarterlyRate, remainingQuarters);
        maturityAmount += amount;
      }

      final totalDeposited = monthlyDeposit * tenureMonths;
      final interestEarned = maturityAmount - totalDeposited;

      setState(
        () => _rdResult = {
          'total_deposited': totalDeposited.round(),
          'maturity_amount': maturityAmount.round(),
          'interest_earned': interestEarned.round(),
        },
      );
    } catch (e) {
      _showError('RD calculation failed');
    }
    setState(() => _isCalculating = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: WealthInTheme.coral),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment Calculators'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'SIP', icon: Icon(Icons.trending_up, size: 18)),
            Tab(text: 'FD', icon: Icon(Icons.savings, size: 18)),
            Tab(text: 'EMI', icon: Icon(Icons.calculate, size: 18)),
            Tab(text: 'RD', icon: Icon(Icons.account_balance, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSIPCalculator(),
          _buildFDCalculator(),
          _buildEMICalculator(),
          _buildRDCalculator(),
        ],
      ),
    );
  }

  Widget _buildSIPCalculator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCard(
            'SIP Calculator',
            'Calculate returns on your Systematic Investment Plan',
            Icons.trending_up,
            WealthInTheme.emerald,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _sipAmountController,
            label: 'Monthly Investment',
            prefix: '₹',
            suffix: '/month',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _sipRateController,
            label: 'Expected Return Rate',
            suffix: '% p.a.',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _sipYearsController,
            label: 'Investment Period',
            suffix: 'years',
          ),
          const SizedBox(height: 24),
          _buildCalculateButton(
            onPressed: _calculateSIP,
            label: 'Calculate SIP Returns',
            color: Colors.green,
          ),
          if (_sipResult != null) ...[
            const SizedBox(height: 24),
            _buildSIPResult(_sipResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildFDCalculator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCard(
            'FD Calculator',
            'Calculate maturity amount on Fixed Deposit',
            Icons.savings,
            WealthInTheme.navy,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _fdPrincipalController,
            label: 'Principal Amount',
            prefix: '₹',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _fdRateController,
            label: 'Interest Rate',
            suffix: '% p.a.',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _fdYearsController,
            label: 'Tenure',
            suffix: 'years',
          ),
          const SizedBox(height: 24),
          _buildCalculateButton(
            onPressed: _calculateFD,
            label: 'Calculate FD Maturity',
            color: Colors.blue,
          ),
          if (_fdResult != null) ...[
            const SizedBox(height: 24),
            _buildFDResult(_fdResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildEMICalculator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCard(
            'EMI Calculator',
            'Calculate your Equated Monthly Installment',
            Icons.calculate,
            WealthInTheme.gold,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _emiPrincipalController,
            label: 'Loan Amount',
            prefix: '₹',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emiRateController,
            label: 'Interest Rate',
            suffix: '% p.a.',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emiYearsController,
            label: 'Loan Tenure',
            suffix: 'years',
          ),
          const SizedBox(height: 24),
          _buildCalculateButton(
            onPressed: _calculateEMI,
            label: 'Calculate EMI',
            color: Colors.orange,
          ),
          if (_emiResult != null) ...[
            const SizedBox(height: 24),
            _buildEMIResult(_emiResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildRDCalculator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCard(
            'RD Calculator',
            'Calculate Recurring Deposit maturity amount',
            Icons.account_balance,
            WealthInTheme.purple,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _rdAmountController,
            label: 'Monthly Deposit',
            prefix: '₹',
            suffix: '/month',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _rdRateController,
            label: 'Interest Rate',
            suffix: '% p.a.',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _rdYearsController,
            label: 'Tenure',
            suffix: 'years',
          ),
          const SizedBox(height: 24),
          _buildCalculateButton(
            onPressed: _calculateRD,
            label: 'Calculate RD Maturity',
            color: Colors.purple,
          ),
          if (_rdResult != null) ...[
            const SizedBox(height: 24),
            _buildRDResult(_rdResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: WealthInTheme.gray600),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }

  Widget _buildCalculateButton({
    required VoidCallback onPressed,
    required String label,
    required Color color,
  }) {
    return FilledButton.icon(
      onPressed: _isCalculating ? null : onPressed,
      icon: _isCalculating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.calculate),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSIPResult(Map<String, dynamic> result) {
    final totalInvested = result['total_invested'] ?? 0;
    final futureValue = result['future_value'] ?? 0;
    final wealthGained = result['wealth_gained'] ?? 0;
    final returns = result['returns_percentage'] ?? 0;

    return _buildResultCard(
      title: 'SIP Projection',
      color: Colors.green,
      items: [
        _ResultItem('Total Invested', _formatCurrency(totalInvested), false),
        _ResultItem('Future Value', _formatCurrency(futureValue), true),
        _ResultItem('Wealth Gained', _formatCurrency(wealthGained), false),
        _ResultItem('Total Returns', '$returns%', false),
      ],
      investedAmount: totalInvested.toDouble(),
      returns: wealthGained.toDouble(),
    );
  }

  Widget _buildFDResult(Map<String, dynamic> result) {
    final principal = result['principal'] ?? 0;
    final maturity = result['maturity_amount'] ?? 0;
    final interest = result['interest_earned'] ?? 0;
    final effectiveRate = result['effective_annual_rate'] ?? 0;

    return _buildResultCard(
      title: 'FD Maturity',
      color: Colors.blue,
      items: [
        _ResultItem('Principal', _formatCurrency(principal), false),
        _ResultItem('Maturity Amount', _formatCurrency(maturity), true),
        _ResultItem('Interest Earned', _formatCurrency(interest), false),
        _ResultItem('Effective Rate', '$effectiveRate% p.a.', false),
      ],
      investedAmount: principal.toDouble(),
      returns: interest.toDouble(),
    );
  }

  Widget _buildEMIResult(Map<String, dynamic> result) {
    final principal = result['principal'] ?? 0;
    final emi = result['emi'] ?? 0;
    final totalPayment = result['total_payment'] ?? 0;
    final totalInterest = result['total_interest'] ?? 0;

    return _buildResultCard(
      title: 'EMI Breakdown',
      color: Colors.orange,
      items: [
        _ResultItem('Loan Amount', _formatCurrency(principal), false),
        _ResultItem('Monthly EMI', _formatCurrency(emi), true),
        _ResultItem('Total Payment', _formatCurrency(totalPayment), false),
        _ResultItem('Total Interest', _formatCurrency(totalInterest), false),
      ],
      investedAmount: principal.toDouble(),
      returns: totalInterest.toDouble(),
      isLoan: true,
    );
  }

  Widget _buildRDResult(Map<String, dynamic> result) {
    final totalDeposited = result['total_deposited'] ?? 0;
    final maturity = result['maturity_amount'] ?? 0;
    final interest = result['interest_earned'] ?? 0;

    return _buildResultCard(
      title: 'RD Maturity',
      color: Colors.purple,
      items: [
        _ResultItem('Total Deposited', _formatCurrency(totalDeposited), false),
        _ResultItem('Maturity Amount', _formatCurrency(maturity), true),
        _ResultItem('Interest Earned', _formatCurrency(interest), false),
      ],
      investedAmount: totalDeposited.toDouble(),
      returns: interest.toDouble(),
    );
  }

  Widget _buildResultCard({
    required String title,
    required Color color,
    required List<_ResultItem> items,
    required double investedAmount,
    required double returns,
    bool isLoan = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Visual Breakdown (Pie-like representation)
                SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                value:
                                    investedAmount / (investedAmount + returns),
                                strokeWidth: 12,
                                backgroundColor: color.withValues(alpha: 0.3),
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isLoan ? 'Interest' : 'Returns',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${((returns / (investedAmount + returns)) * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LegendItem(
                              color: color,
                              label: isLoan ? 'Principal' : 'Invested',
                              value: _formatCurrency(investedAmount.round()),
                            ),
                            const SizedBox(height: 8),
                            _LegendItem(
                              color: color.withValues(alpha: 0.3),
                              label: isLoan ? 'Interest' : 'Returns',
                              value: _formatCurrency(returns.round()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),
                // Result Items
                ...items.map((item) => _buildResultRow(item, color)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildResultRow(_ResultItem item, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            item.label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: item.isHighlighted ? 14 : 13,
            ),
          ),
          Text(
            item.value,
            style: TextStyle(
              fontWeight: item.isHighlighted
                  ? FontWeight.bold
                  : FontWeight.w600,
              fontSize: item.isHighlighted ? 18 : 14,
              color: item.isHighlighted ? color : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(num value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)} L';
    }
    return '₹${value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }
}

class _ResultItem {
  final String label;
  final String value;
  final bool isHighlighted;

  _ResultItem(this.label, this.value, this.isHighlighted);
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
