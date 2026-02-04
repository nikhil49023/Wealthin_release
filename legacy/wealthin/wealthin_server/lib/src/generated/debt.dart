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

/// Debt model for tracking loans, EMIs, and credit
abstract class Debt implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  Debt._({
    this.id,
    required this.userProfileId,
    required this.name,
    required this.debtType,
    required this.principal,
    required this.interestRate,
    this.emi,
    required this.startDate,
    this.tenureMonths,
    required this.remainingAmount,
    this.nextDueDate,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.notes,
  });

  factory Debt({
    int? id,
    required int userProfileId,
    required String name,
    required String debtType,
    required double principal,
    required double interestRate,
    double? emi,
    required DateTime startDate,
    int? tenureMonths,
    required double remainingAmount,
    DateTime? nextDueDate,
    required String status,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? notes,
  }) = _DebtImpl;

  factory Debt.fromJson(Map<String, dynamic> jsonSerialization) {
    return Debt(
      id: jsonSerialization['id'] as int?,
      userProfileId: jsonSerialization['userProfileId'] as int,
      name: jsonSerialization['name'] as String,
      debtType: jsonSerialization['debtType'] as String,
      principal: (jsonSerialization['principal'] as num).toDouble(),
      interestRate: (jsonSerialization['interestRate'] as num).toDouble(),
      emi: (jsonSerialization['emi'] as num?)?.toDouble(),
      startDate: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['startDate'],
      ),
      tenureMonths: jsonSerialization['tenureMonths'] as int?,
      remainingAmount: (jsonSerialization['remainingAmount'] as num).toDouble(),
      nextDueDate: jsonSerialization['nextDueDate'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['nextDueDate'],
            ),
      status: jsonSerialization['status'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
      notes: jsonSerialization['notes'] as String?,
    );
  }

  static final t = DebtTable();

  static const db = DebtRepository._();

  @override
  int? id;

  int userProfileId;

  String name;

  String debtType;

  double principal;

  double interestRate;

  double? emi;

  DateTime startDate;

  int? tenureMonths;

  double remainingAmount;

  DateTime? nextDueDate;

  String status;

  DateTime createdAt;

  DateTime? updatedAt;

  String? notes;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [Debt]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Debt copyWith({
    int? id,
    int? userProfileId,
    String? name,
    String? debtType,
    double? principal,
    double? interestRate,
    double? emi,
    DateTime? startDate,
    int? tenureMonths,
    double? remainingAmount,
    DateTime? nextDueDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Debt',
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      'name': name,
      'debtType': debtType,
      'principal': principal,
      'interestRate': interestRate,
      if (emi != null) 'emi': emi,
      'startDate': startDate.toJson(),
      if (tenureMonths != null) 'tenureMonths': tenureMonths,
      'remainingAmount': remainingAmount,
      if (nextDueDate != null) 'nextDueDate': nextDueDate?.toJson(),
      'status': status,
      'createdAt': createdAt.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      if (notes != null) 'notes': notes,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Debt',
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      'name': name,
      'debtType': debtType,
      'principal': principal,
      'interestRate': interestRate,
      if (emi != null) 'emi': emi,
      'startDate': startDate.toJson(),
      if (tenureMonths != null) 'tenureMonths': tenureMonths,
      'remainingAmount': remainingAmount,
      if (nextDueDate != null) 'nextDueDate': nextDueDate?.toJson(),
      'status': status,
      'createdAt': createdAt.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      if (notes != null) 'notes': notes,
    };
  }

  static DebtInclude include() {
    return DebtInclude._();
  }

  static DebtIncludeList includeList({
    _i1.WhereExpressionBuilder<DebtTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DebtTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DebtTable>? orderByList,
    DebtInclude? include,
  }) {
    return DebtIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Debt.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(Debt.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DebtImpl extends Debt {
  _DebtImpl({
    int? id,
    required int userProfileId,
    required String name,
    required String debtType,
    required double principal,
    required double interestRate,
    double? emi,
    required DateTime startDate,
    int? tenureMonths,
    required double remainingAmount,
    DateTime? nextDueDate,
    required String status,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? notes,
  }) : super._(
         id: id,
         userProfileId: userProfileId,
         name: name,
         debtType: debtType,
         principal: principal,
         interestRate: interestRate,
         emi: emi,
         startDate: startDate,
         tenureMonths: tenureMonths,
         remainingAmount: remainingAmount,
         nextDueDate: nextDueDate,
         status: status,
         createdAt: createdAt,
         updatedAt: updatedAt,
         notes: notes,
       );

  /// Returns a shallow copy of this [Debt]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Debt copyWith({
    Object? id = _Undefined,
    int? userProfileId,
    String? name,
    String? debtType,
    double? principal,
    double? interestRate,
    Object? emi = _Undefined,
    DateTime? startDate,
    Object? tenureMonths = _Undefined,
    double? remainingAmount,
    Object? nextDueDate = _Undefined,
    String? status,
    DateTime? createdAt,
    Object? updatedAt = _Undefined,
    Object? notes = _Undefined,
  }) {
    return Debt(
      id: id is int? ? id : this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      name: name ?? this.name,
      debtType: debtType ?? this.debtType,
      principal: principal ?? this.principal,
      interestRate: interestRate ?? this.interestRate,
      emi: emi is double? ? emi : this.emi,
      startDate: startDate ?? this.startDate,
      tenureMonths: tenureMonths is int? ? tenureMonths : this.tenureMonths,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      nextDueDate: nextDueDate is DateTime? ? nextDueDate : this.nextDueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt is DateTime? ? updatedAt : this.updatedAt,
      notes: notes is String? ? notes : this.notes,
    );
  }
}

class DebtUpdateTable extends _i1.UpdateTable<DebtTable> {
  DebtUpdateTable(super.table);

  _i1.ColumnValue<int, int> userProfileId(int value) => _i1.ColumnValue(
    table.userProfileId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<String, String> debtType(String value) => _i1.ColumnValue(
    table.debtType,
    value,
  );

  _i1.ColumnValue<double, double> principal(double value) => _i1.ColumnValue(
    table.principal,
    value,
  );

  _i1.ColumnValue<double, double> interestRate(double value) => _i1.ColumnValue(
    table.interestRate,
    value,
  );

  _i1.ColumnValue<double, double> emi(double? value) => _i1.ColumnValue(
    table.emi,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> startDate(DateTime value) =>
      _i1.ColumnValue(
        table.startDate,
        value,
      );

  _i1.ColumnValue<int, int> tenureMonths(int? value) => _i1.ColumnValue(
    table.tenureMonths,
    value,
  );

  _i1.ColumnValue<double, double> remainingAmount(double value) =>
      _i1.ColumnValue(
        table.remainingAmount,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> nextDueDate(DateTime? value) =>
      _i1.ColumnValue(
        table.nextDueDate,
        value,
      );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
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

class DebtTable extends _i1.Table<int?> {
  DebtTable({super.tableRelation}) : super(tableName: 'debts') {
    updateTable = DebtUpdateTable(this);
    userProfileId = _i1.ColumnInt(
      'userProfileId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
    debtType = _i1.ColumnString(
      'debtType',
      this,
    );
    principal = _i1.ColumnDouble(
      'principal',
      this,
    );
    interestRate = _i1.ColumnDouble(
      'interestRate',
      this,
    );
    emi = _i1.ColumnDouble(
      'emi',
      this,
    );
    startDate = _i1.ColumnDateTime(
      'startDate',
      this,
    );
    tenureMonths = _i1.ColumnInt(
      'tenureMonths',
      this,
    );
    remainingAmount = _i1.ColumnDouble(
      'remainingAmount',
      this,
    );
    nextDueDate = _i1.ColumnDateTime(
      'nextDueDate',
      this,
    );
    status = _i1.ColumnString(
      'status',
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

  late final DebtUpdateTable updateTable;

  late final _i1.ColumnInt userProfileId;

  late final _i1.ColumnString name;

  late final _i1.ColumnString debtType;

  late final _i1.ColumnDouble principal;

  late final _i1.ColumnDouble interestRate;

  late final _i1.ColumnDouble emi;

  late final _i1.ColumnDateTime startDate;

  late final _i1.ColumnInt tenureMonths;

  late final _i1.ColumnDouble remainingAmount;

  late final _i1.ColumnDateTime nextDueDate;

  late final _i1.ColumnString status;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnString notes;

  @override
  List<_i1.Column> get columns => [
    id,
    userProfileId,
    name,
    debtType,
    principal,
    interestRate,
    emi,
    startDate,
    tenureMonths,
    remainingAmount,
    nextDueDate,
    status,
    createdAt,
    updatedAt,
    notes,
  ];
}

class DebtInclude extends _i1.IncludeObject {
  DebtInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => Debt.t;
}

class DebtIncludeList extends _i1.IncludeList {
  DebtIncludeList._({
    _i1.WhereExpressionBuilder<DebtTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Debt.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => Debt.t;
}

class DebtRepository {
  const DebtRepository._();

  /// Returns a list of [Debt]s matching the given query parameters.
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
  Future<List<Debt>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DebtTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DebtTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DebtTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<Debt>(
      where: where?.call(Debt.t),
      orderBy: orderBy?.call(Debt.t),
      orderByList: orderByList?.call(Debt.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [Debt] matching the given query parameters.
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
  Future<Debt?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DebtTable>? where,
    int? offset,
    _i1.OrderByBuilder<DebtTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DebtTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<Debt>(
      where: where?.call(Debt.t),
      orderBy: orderBy?.call(Debt.t),
      orderByList: orderByList?.call(Debt.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [Debt] by its [id] or null if no such row exists.
  Future<Debt?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<Debt>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [Debt]s in the list and returns the inserted rows.
  ///
  /// The returned [Debt]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<Debt>> insert(
    _i1.Session session,
    List<Debt> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<Debt>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [Debt] and returns the inserted row.
  ///
  /// The returned [Debt] will have its `id` field set.
  Future<Debt> insertRow(
    _i1.Session session,
    Debt row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Debt>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [Debt]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<Debt>> update(
    _i1.Session session,
    List<Debt> rows, {
    _i1.ColumnSelections<DebtTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<Debt>(
      rows,
      columns: columns?.call(Debt.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Debt]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Debt> updateRow(
    _i1.Session session,
    Debt row, {
    _i1.ColumnSelections<DebtTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Debt>(
      row,
      columns: columns?.call(Debt.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Debt] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Debt?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<DebtUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Debt>(
      id,
      columnValues: columnValues(Debt.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Debt]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<Debt>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<DebtUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<DebtTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DebtTable>? orderBy,
    _i1.OrderByListBuilder<DebtTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<Debt>(
      columnValues: columnValues(Debt.t.updateTable),
      where: where(Debt.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Debt.t),
      orderByList: orderByList?.call(Debt.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [Debt]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<Debt>> delete(
    _i1.Session session,
    List<Debt> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Debt>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [Debt].
  Future<Debt> deleteRow(
    _i1.Session session,
    Debt row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Debt>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<Debt>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<DebtTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<Debt>(
      where: where(Debt.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DebtTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Debt>(
      where: where?.call(Debt.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
