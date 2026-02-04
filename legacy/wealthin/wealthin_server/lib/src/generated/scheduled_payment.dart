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
import 'package:serverpod/serverpod.dart' as _i1;

/// ScheduledPayment model for recurring payment reminders
abstract class ScheduledPayment
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ScheduledPayment._({
    this.id,
    required this.userProfileId,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.nextDueDate,
    required this.autoTrack,
    this.category,
    required this.isActive,
    this.lastPaidDate,
    required this.createdAt,
    this.updatedAt,
    this.notes,
  });

  factory ScheduledPayment({
    int? id,
    required int userProfileId,
    required String name,
    required double amount,
    required String frequency,
    required DateTime nextDueDate,
    required bool autoTrack,
    String? category,
    required bool isActive,
    DateTime? lastPaidDate,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? notes,
  }) = _ScheduledPaymentImpl;

  factory ScheduledPayment.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScheduledPayment(
      id: jsonSerialization['id'] as int?,
      userProfileId: jsonSerialization['userProfileId'] as int,
      name: jsonSerialization['name'] as String,
      amount: (jsonSerialization['amount'] as num).toDouble(),
      frequency: jsonSerialization['frequency'] as String,
      nextDueDate: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['nextDueDate'],
      ),
      autoTrack: jsonSerialization['autoTrack'] as bool,
      category: jsonSerialization['category'] as String?,
      isActive: jsonSerialization['isActive'] as bool,
      lastPaidDate: jsonSerialization['lastPaidDate'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastPaidDate'],
            ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
      notes: jsonSerialization['notes'] as String?,
    );
  }

  static final t = ScheduledPaymentTable();

  static const db = ScheduledPaymentRepository._();

  @override
  int? id;

  int userProfileId;

  String name;

  double amount;

  String frequency;

  DateTime nextDueDate;

  bool autoTrack;

  String? category;

  bool isActive;

  DateTime? lastPaidDate;

  DateTime createdAt;

  DateTime? updatedAt;

  String? notes;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ScheduledPayment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ScheduledPayment copyWith({
    int? id,
    int? userProfileId,
    String? name,
    double? amount,
    String? frequency,
    DateTime? nextDueDate,
    bool? autoTrack,
    String? category,
    bool? isActive,
    DateTime? lastPaidDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScheduledPayment',
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      'name': name,
      'amount': amount,
      'frequency': frequency,
      'nextDueDate': nextDueDate.toJson(),
      'autoTrack': autoTrack,
      if (category != null) 'category': category,
      'isActive': isActive,
      if (lastPaidDate != null) 'lastPaidDate': lastPaidDate?.toJson(),
      'createdAt': createdAt.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      if (notes != null) 'notes': notes,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ScheduledPayment',
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      'name': name,
      'amount': amount,
      'frequency': frequency,
      'nextDueDate': nextDueDate.toJson(),
      'autoTrack': autoTrack,
      if (category != null) 'category': category,
      'isActive': isActive,
      if (lastPaidDate != null) 'lastPaidDate': lastPaidDate?.toJson(),
      'createdAt': createdAt.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      if (notes != null) 'notes': notes,
    };
  }

  static ScheduledPaymentInclude include() {
    return ScheduledPaymentInclude._();
  }

  static ScheduledPaymentIncludeList includeList({
    _i1.WhereExpressionBuilder<ScheduledPaymentTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ScheduledPaymentTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ScheduledPaymentTable>? orderByList,
    ScheduledPaymentInclude? include,
  }) {
    return ScheduledPaymentIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScheduledPayment.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ScheduledPayment.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ScheduledPaymentImpl extends ScheduledPayment {
  _ScheduledPaymentImpl({
    int? id,
    required int userProfileId,
    required String name,
    required double amount,
    required String frequency,
    required DateTime nextDueDate,
    required bool autoTrack,
    String? category,
    required bool isActive,
    DateTime? lastPaidDate,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? notes,
  }) : super._(
         id: id,
         userProfileId: userProfileId,
         name: name,
         amount: amount,
         frequency: frequency,
         nextDueDate: nextDueDate,
         autoTrack: autoTrack,
         category: category,
         isActive: isActive,
         lastPaidDate: lastPaidDate,
         createdAt: createdAt,
         updatedAt: updatedAt,
         notes: notes,
       );

  /// Returns a shallow copy of this [ScheduledPayment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ScheduledPayment copyWith({
    Object? id = _Undefined,
    int? userProfileId,
    String? name,
    double? amount,
    String? frequency,
    DateTime? nextDueDate,
    bool? autoTrack,
    Object? category = _Undefined,
    bool? isActive,
    Object? lastPaidDate = _Undefined,
    DateTime? createdAt,
    Object? updatedAt = _Undefined,
    Object? notes = _Undefined,
  }) {
    return ScheduledPayment(
      id: id is int? ? id : this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      autoTrack: autoTrack ?? this.autoTrack,
      category: category is String? ? category : this.category,
      isActive: isActive ?? this.isActive,
      lastPaidDate: lastPaidDate is DateTime?
          ? lastPaidDate
          : this.lastPaidDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt is DateTime? ? updatedAt : this.updatedAt,
      notes: notes is String? ? notes : this.notes,
    );
  }
}

class ScheduledPaymentUpdateTable
    extends _i1.UpdateTable<ScheduledPaymentTable> {
  ScheduledPaymentUpdateTable(super.table);

  _i1.ColumnValue<int, int> userProfileId(int value) => _i1.ColumnValue(
    table.userProfileId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<double, double> amount(double value) => _i1.ColumnValue(
    table.amount,
    value,
  );

  _i1.ColumnValue<String, String> frequency(String value) => _i1.ColumnValue(
    table.frequency,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> nextDueDate(DateTime value) =>
      _i1.ColumnValue(
        table.nextDueDate,
        value,
      );

  _i1.ColumnValue<bool, bool> autoTrack(bool value) => _i1.ColumnValue(
    table.autoTrack,
    value,
  );

  _i1.ColumnValue<String, String> category(String? value) => _i1.ColumnValue(
    table.category,
    value,
  );

  _i1.ColumnValue<bool, bool> isActive(bool value) => _i1.ColumnValue(
    table.isActive,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> lastPaidDate(DateTime? value) =>
      _i1.ColumnValue(
        table.lastPaidDate,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );

  _i1.ColumnValue<String, String> notes(String? value) => _i1.ColumnValue(
    table.notes,
    value,
  );
}

class ScheduledPaymentTable extends _i1.Table<int?> {
  ScheduledPaymentTable({super.tableRelation})
    : super(tableName: 'scheduled_payments') {
    updateTable = ScheduledPaymentUpdateTable(this);
    userProfileId = _i1.ColumnInt(
      'userProfileId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
    amount = _i1.ColumnDouble(
      'amount',
      this,
    );
    frequency = _i1.ColumnString(
      'frequency',
      this,
    );
    nextDueDate = _i1.ColumnDateTime(
      'nextDueDate',
      this,
    );
    autoTrack = _i1.ColumnBool(
      'autoTrack',
      this,
    );
    category = _i1.ColumnString(
      'category',
      this,
    );
    isActive = _i1.ColumnBool(
      'isActive',
      this,
    );
    lastPaidDate = _i1.ColumnDateTime(
      'lastPaidDate',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
    );
    notes = _i1.ColumnString(
      'notes',
      this,
    );
  }

  late final ScheduledPaymentUpdateTable updateTable;

  late final _i1.ColumnInt userProfileId;

  late final _i1.ColumnString name;

  late final _i1.ColumnDouble amount;

  late final _i1.ColumnString frequency;

  late final _i1.ColumnDateTime nextDueDate;

  late final _i1.ColumnBool autoTrack;

  late final _i1.ColumnString category;

  late final _i1.ColumnBool isActive;

  late final _i1.ColumnDateTime lastPaidDate;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnString notes;

  @override
  List<_i1.Column> get columns => [
    id,
    userProfileId,
    name,
    amount,
    frequency,
    nextDueDate,
    autoTrack,
    category,
    isActive,
    lastPaidDate,
    createdAt,
    updatedAt,
    notes,
  ];
}

class ScheduledPaymentInclude extends _i1.IncludeObject {
  ScheduledPaymentInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => ScheduledPayment.t;
}

class ScheduledPaymentIncludeList extends _i1.IncludeList {
  ScheduledPaymentIncludeList._({
    _i1.WhereExpressionBuilder<ScheduledPaymentTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ScheduledPayment.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ScheduledPayment.t;
}

class ScheduledPaymentRepository {
  const ScheduledPaymentRepository._();

  /// Returns a list of [ScheduledPayment]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<ScheduledPayment>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<ScheduledPaymentTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ScheduledPaymentTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ScheduledPaymentTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<ScheduledPayment>(
      where: where?.call(ScheduledPayment.t),
      orderBy: orderBy?.call(ScheduledPayment.t),
      orderByList: orderByList?.call(ScheduledPayment.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [ScheduledPayment] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<ScheduledPayment?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<ScheduledPaymentTable>? where,
    int? offset,
    _i1.OrderByBuilder<ScheduledPaymentTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ScheduledPaymentTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<ScheduledPayment>(
      where: where?.call(ScheduledPayment.t),
      orderBy: orderBy?.call(ScheduledPayment.t),
      orderByList: orderByList?.call(ScheduledPayment.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [ScheduledPayment] by its [id] or null if no such row exists.
  Future<ScheduledPayment?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<ScheduledPayment>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [ScheduledPayment]s in the list and returns the inserted rows.
  ///
  /// The returned [ScheduledPayment]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<ScheduledPayment>> insert(
    _i1.Session session,
    List<ScheduledPayment> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<ScheduledPayment>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [ScheduledPayment] and returns the inserted row.
  ///
  /// The returned [ScheduledPayment] will have its `id` field set.
  Future<ScheduledPayment> insertRow(
    _i1.Session session,
    ScheduledPayment row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ScheduledPayment>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ScheduledPayment]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ScheduledPayment>> update(
    _i1.Session session,
    List<ScheduledPayment> rows, {
    _i1.ColumnSelections<ScheduledPaymentTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ScheduledPayment>(
      rows,
      columns: columns?.call(ScheduledPayment.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ScheduledPayment]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ScheduledPayment> updateRow(
    _i1.Session session,
    ScheduledPayment row, {
    _i1.ColumnSelections<ScheduledPaymentTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ScheduledPayment>(
      row,
      columns: columns?.call(ScheduledPayment.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ScheduledPayment] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ScheduledPayment?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<ScheduledPaymentUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ScheduledPayment>(
      id,
      columnValues: columnValues(ScheduledPayment.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ScheduledPayment]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ScheduledPayment>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<ScheduledPaymentUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<ScheduledPaymentTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ScheduledPaymentTable>? orderBy,
    _i1.OrderByListBuilder<ScheduledPaymentTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ScheduledPayment>(
      columnValues: columnValues(ScheduledPayment.t.updateTable),
      where: where(ScheduledPayment.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ScheduledPayment.t),
      orderByList: orderByList?.call(ScheduledPayment.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ScheduledPayment]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ScheduledPayment>> delete(
    _i1.Session session,
    List<ScheduledPayment> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ScheduledPayment>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ScheduledPayment].
  Future<ScheduledPayment> deleteRow(
    _i1.Session session,
    ScheduledPayment row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ScheduledPayment>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ScheduledPayment>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<ScheduledPaymentTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ScheduledPayment>(
      where: where(ScheduledPayment.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<ScheduledPaymentTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ScheduledPayment>(
      where: where?.call(ScheduledPayment.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
