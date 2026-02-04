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
import 'agent_action.dart' as _i2;
import 'budget.dart' as _i3;
import 'business_idea.dart' as _i4;
import 'dashboard_data.dart' as _i5;
import 'debt.dart' as _i6;
import 'goal.dart' as _i7;
import 'greetings/greeting.dart' as _i8;
import 'scheduled_payment.dart' as _i9;
import 'transaction.dart' as _i10;
import 'user_profile.dart' as _i11;
import 'package:wealthin_client/src/protocol/transaction.dart' as _i12;
import 'package:wealthin_client/src/protocol/agent_action.dart' as _i13;
import 'package:wealthin_client/src/protocol/budget.dart' as _i14;
import 'package:wealthin_client/src/protocol/debt.dart' as _i15;
import 'package:wealthin_client/src/protocol/goal.dart' as _i16;
import 'package:wealthin_client/src/protocol/scheduled_payment.dart' as _i17;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i18;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i19;
export 'agent_action.dart';
export 'budget.dart';
export 'business_idea.dart';
export 'dashboard_data.dart';
export 'debt.dart';
export 'goal.dart';
export 'greetings/greeting.dart';
export 'scheduled_payment.dart';
export 'transaction.dart';
export 'user_profile.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i2.AgentAction) {
      return _i2.AgentAction.fromJson(data) as T;
    }
    if (t == _i3.Budget) {
      return _i3.Budget.fromJson(data) as T;
    }
    if (t == _i4.BusinessIdea) {
      return _i4.BusinessIdea.fromJson(data) as T;
    }
    if (t == _i5.DashboardData) {
      return _i5.DashboardData.fromJson(data) as T;
    }
    if (t == _i6.Debt) {
      return _i6.Debt.fromJson(data) as T;
    }
    if (t == _i7.Goal) {
      return _i7.Goal.fromJson(data) as T;
    }
    if (t == _i8.Greeting) {
      return _i8.Greeting.fromJson(data) as T;
    }
    if (t == _i9.ScheduledPayment) {
      return _i9.ScheduledPayment.fromJson(data) as T;
    }
    if (t == _i10.Transaction) {
      return _i10.Transaction.fromJson(data) as T;
    }
    if (t == _i11.UserProfile) {
      return _i11.UserProfile.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.AgentAction?>()) {
      return (data != null ? _i2.AgentAction.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.Budget?>()) {
      return (data != null ? _i3.Budget.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.BusinessIdea?>()) {
      return (data != null ? _i4.BusinessIdea.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.DashboardData?>()) {
      return (data != null ? _i5.DashboardData.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.Debt?>()) {
      return (data != null ? _i6.Debt.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.Goal?>()) {
      return (data != null ? _i7.Goal.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.Greeting?>()) {
      return (data != null ? _i8.Greeting.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.ScheduledPayment?>()) {
      return (data != null ? _i9.ScheduledPayment.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.Transaction?>()) {
      return (data != null ? _i10.Transaction.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.UserProfile?>()) {
      return (data != null ? _i11.UserProfile.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i10.Transaction>) {
      return (data as List)
              .map((e) => deserialize<_i10.Transaction>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<String>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<String>(e)).toList()
              : null)
          as T;
    }
    if (t == Map<String, dynamic>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<dynamic>(v)),
          )
          as T;
    }
    if (t == List<_i12.Transaction>) {
      return (data as List)
              .map((e) => deserialize<_i12.Transaction>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i12.Transaction>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i12.Transaction>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i13.AgentAction>) {
      return (data as List)
              .map((e) => deserialize<_i13.AgentAction>(e))
              .toList()
          as T;
    }
    if (t == List<Map<String, dynamic>>) {
      return (data as List)
              .map((e) => deserialize<Map<String, dynamic>>(e))
              .toList()
          as T;
    }
    if (t == List<_i14.Budget>) {
      return (data as List).map((e) => deserialize<_i14.Budget>(e)).toList()
          as T;
    }
    if (t == List<_i15.Debt>) {
      return (data as List).map((e) => deserialize<_i15.Debt>(e)).toList() as T;
    }
    if (t == List<_i16.Goal>) {
      return (data as List).map((e) => deserialize<_i16.Goal>(e)).toList() as T;
    }
    if (t == List<_i17.ScheduledPayment>) {
      return (data as List)
              .map((e) => deserialize<_i17.ScheduledPayment>(e))
              .toList()
          as T;
    }
    try {
      return _i18.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i19.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.AgentAction => 'AgentAction',
      _i3.Budget => 'Budget',
      _i4.BusinessIdea => 'BusinessIdea',
      _i5.DashboardData => 'DashboardData',
      _i6.Debt => 'Debt',
      _i7.Goal => 'Goal',
      _i8.Greeting => 'Greeting',
      _i9.ScheduledPayment => 'ScheduledPayment',
      _i10.Transaction => 'Transaction',
      _i11.UserProfile => 'UserProfile',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('wealthin.', '');
    }

    switch (data) {
      case _i2.AgentAction():
        return 'AgentAction';
      case _i3.Budget():
        return 'Budget';
      case _i4.BusinessIdea():
        return 'BusinessIdea';
      case _i5.DashboardData():
        return 'DashboardData';
      case _i6.Debt():
        return 'Debt';
      case _i7.Goal():
        return 'Goal';
      case _i8.Greeting():
        return 'Greeting';
      case _i9.ScheduledPayment():
        return 'ScheduledPayment';
      case _i10.Transaction():
        return 'Transaction';
      case _i11.UserProfile():
        return 'UserProfile';
    }
    className = _i18.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i19.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'AgentAction') {
      return deserialize<_i2.AgentAction>(data['data']);
    }
    if (dataClassName == 'Budget') {
      return deserialize<_i3.Budget>(data['data']);
    }
    if (dataClassName == 'BusinessIdea') {
      return deserialize<_i4.BusinessIdea>(data['data']);
    }
    if (dataClassName == 'DashboardData') {
      return deserialize<_i5.DashboardData>(data['data']);
    }
    if (dataClassName == 'Debt') {
      return deserialize<_i6.Debt>(data['data']);
    }
    if (dataClassName == 'Goal') {
      return deserialize<_i7.Goal>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_i8.Greeting>(data['data']);
    }
    if (dataClassName == 'ScheduledPayment') {
      return deserialize<_i9.ScheduledPayment>(data['data']);
    }
    if (dataClassName == 'Transaction') {
      return deserialize<_i10.Transaction>(data['data']);
    }
    if (dataClassName == 'UserProfile') {
      return deserialize<_i11.UserProfile>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i18.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i19.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i18.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i19.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
