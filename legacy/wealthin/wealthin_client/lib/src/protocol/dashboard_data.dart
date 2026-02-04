/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'transaction.dart' as _i2;
import 'package:wealthin_client/src/protocol/protocol.dart' as _i3;

abstract class DashboardData implements _i1.SerializableModel {
  DashboardData._({
    required this.netWorth,
    required this.totalIncome,
    required this.totalExpenses,
    required this.savingsRate,
    required this.recentTransactions,
    required this.financialHealthScore,
    required this.aiSuggestion,
  });

  factory DashboardData({
    required double netWorth,
    required double totalIncome,
    required double totalExpenses,
    required int savingsRate,
    required List<_i2.Transaction> recentTransactions,
    required int financialHealthScore,
    required String aiSuggestion,
  }) = _DashboardDataImpl;

  factory DashboardData.fromJson(Map<String, dynamic> jsonSerialization) {
    return DashboardData(
      netWorth: (jsonSerialization['netWorth'] as num).toDouble(),
      totalIncome: (jsonSerialization['totalIncome'] as num).toDouble(),
      totalExpenses: (jsonSerialization['totalExpenses'] as num).toDouble(),
      savingsRate: jsonSerialization['savingsRate'] as int,
      recentTransactions: _i3.Protocol().deserialize<List<_i2.Transaction>>(
        jsonSerialization['recentTransactions'],
      ),
      financialHealthScore: jsonSerialization['financialHealthScore'] as int,
      aiSuggestion: jsonSerialization['aiSuggestion'] as String,
    );
  }

  double netWorth;

  double totalIncome;

  double totalExpenses;

  int savingsRate;

  List<_i2.Transaction> recentTransactions;

  int financialHealthScore;

  String aiSuggestion;

  /// Returns a shallow copy of this [DashboardData]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DashboardData copyWith({
    double? netWorth,
    double? totalIncome,
    double? totalExpenses,
    int? savingsRate,
    List<_i2.Transaction>? recentTransactions,
    int? financialHealthScore,
    String? aiSuggestion,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DashboardData',
      'netWorth': netWorth,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'savingsRate': savingsRate,
      'recentTransactions': recentTransactions.toJson(
        valueToJson: (v) => v.toJson(),
      ),
      'financialHealthScore': financialHealthScore,
      'aiSuggestion': aiSuggestion,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _DashboardDataImpl extends DashboardData {
  _DashboardDataImpl({
    required double netWorth,
    required double totalIncome,
    required double totalExpenses,
    required int savingsRate,
    required List<_i2.Transaction> recentTransactions,
    required int financialHealthScore,
    required String aiSuggestion,
  }) : super._(
         netWorth: netWorth,
         totalIncome: totalIncome,
         totalExpenses: totalExpenses,
         savingsRate: savingsRate,
         recentTransactions: recentTransactions,
         financialHealthScore: financialHealthScore,
         aiSuggestion: aiSuggestion,
       );

  /// Returns a shallow copy of this [DashboardData]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DashboardData copyWith({
    double? netWorth,
    double? totalIncome,
    double? totalExpenses,
    int? savingsRate,
    List<_i2.Transaction>? recentTransactions,
    int? financialHealthScore,
    String? aiSuggestion,
  }) {
    return DashboardData(
      netWorth: netWorth ?? this.netWorth,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      savingsRate: savingsRate ?? this.savingsRate,
      recentTransactions:
          recentTransactions ??
          this.recentTransactions.map((e0) => e0.copyWith()).toList(),
      financialHealthScore: financialHealthScore ?? this.financialHealthScore,
      aiSuggestion: aiSuggestion ?? this.aiSuggestion,
    );
  }
}
