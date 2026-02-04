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

abstract class Goal implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  Goal._({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    this.status,
    required this.isDefault,
    required this.userProfileId,
    this.createdAt,
    this.updatedAt,
    this.notes,
  });

  factory Goal({
    int? id,
    required String name,
    required double targetAmount,
    required double currentAmount,
    DateTime? deadline,
    String? status,
    required bool isDefault,
    required int userProfileId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) = _GoalImpl;

  factory Goal.fromJson(Map<String, dynamic> jsonSerialization) {
    return Goal(
      id: jsonSerialization['id'] as int?,
      name: jsonSerialization['name'] as String,
      targetAmount: (jsonSerialization['targetAmount'] as num).toDouble(),
      currentAmount: (jsonSerialization['currentAmount'] as num).toDouble(),
      deadline: jsonSerialization['deadline'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['deadline']),
      status: jsonSerialization['status'] as String?,
      isDefault: jsonSerialization['isDefault'] as bool,
      userProfileId: jsonSerialization['userProfileId'] as int,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
      notes: jsonSerialization['notes'] as String?,
    );
  }

  static final t = GoalTable();

  static const db = GoalRepository._();

  @override
  int? id;

  String name;

  double targetAmount;

  double currentAmount;

  DateTime? deadline;

  String? status;

  bool isDefault;

  int userProfileId;

  DateTime? createdAt;

  DateTime? updatedAt;

  String? notes;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [Goal]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Goal copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    String? status,
    bool? isDefault,
    int? userProfileId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Goal',
      if (id != null) 'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      if (deadline != null) 'deadline': deadline?.toJson(),
      if (status != null) 'status': status,
      'isDefault': isDefault,
      'userProfileId': userProfileId,
      if (createdAt != null) 'createdAt': createdAt?.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      if (notes != null) 'notes': notes,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Goal',
      if (id != null) 'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      if (deadline != null) 'deadline': deadline?.toJson(),
      if (status != null) 'status': status,
      'isDefault': isDefault,
      'userProfileId': userProfileId,
      if (createdAt != null) 'createdAt': createdAt?.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      if (notes != null) 'notes': notes,
    };
  }

  static GoalInclude include() {
    return GoalInclude._();
  }

  static GoalIncludeList includeList({
    _i1.WhereExpressionBuilder<GoalTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<GoalTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<GoalTable>? orderByList,
    GoalInclude? include,
  }) {
    return GoalIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Goal.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(Goal.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _GoalImpl extends Goal {
  _GoalImpl({
    int? id,
    required String name,
    required double targetAmount,
    required double currentAmount,
    DateTime? deadline,
    String? status,
    required bool isDefault,
    required int userProfileId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) : super._(
         id: id,
         name: name,
         targetAmount: targetAmount,
         currentAmount: currentAmount,
         deadline: deadline,
         status: status,
         isDefault: isDefault,
         userProfileId: userProfileId,
         createdAt: createdAt,
         updatedAt: updatedAt,
         notes: notes,
       );

  /// Returns a shallow copy of this [Goal]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Goal copyWith({
    Object? id = _Undefined,
    String? name,
    double? targetAmount,
    double? currentAmount,
    Object? deadline = _Undefined,
    Object? status = _Undefined,
    bool? isDefault,
    int? userProfileId,
    Object? createdAt = _Undefined,
    Object? updatedAt = _Undefined,
    Object? notes = _Undefined,
  }) {
    return Goal(
      id: id is int? ? id : this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline is DateTime? ? deadline : this.deadline,
      status: status is String? ? status : this.status,
      isDefault: isDefault ?? this.isDefault,
      userProfileId: userProfileId ?? this.userProfileId,
      createdAt: createdAt is DateTime? ? createdAt : this.createdAt,
      updatedAt: updatedAt is DateTime? ? updatedAt : this.updatedAt,
      notes: notes is String? ? notes : this.notes,
    );
  }
}

class GoalUpdateTable extends _i1.UpdateTable<GoalTable> {
  GoalUpdateTable(super.table);

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<double, double> targetAmount(double value) => _i1.ColumnValue(
    table.targetAmount,
    value,
  );

  _i1.ColumnValue<double, double> currentAmount(double value) =>
      _i1.ColumnValue(
        table.currentAmount,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> deadline(DateTime? value) =>
      _i1.ColumnValue(
        table.deadline,
        value,
      );

  _i1.ColumnValue<String, String> status(String? value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<bool, bool> isDefault(bool value) => _i1.ColumnValue(
    table.isDefault,
    value,
  );

  _i1.ColumnValue<int, int> userProfileId(int value) => _i1.ColumnValue(
    table.userProfileId,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime? value) =>
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

class GoalTable extends _i1.Table<int?> {
  GoalTable({super.tableRelation}) : super(tableName: 'goals') {
    updateTable = GoalUpdateTable(this);
    name = _i1.ColumnString(
      'name',
      this,
    );
    targetAmount = _i1.ColumnDouble(
      'targetAmount',
      this,
    );
    currentAmount = _i1.ColumnDouble(
      'currentAmount',
      this,
    );
    deadline = _i1.ColumnDateTime(
      'deadline',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    isDefault = _i1.ColumnBool(
      'isDefault',
      this,
    );
    userProfileId = _i1.ColumnInt(
      'userProfileId',
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

  late final GoalUpdateTable updateTable;

  late final _i1.ColumnString name;

  late final _i1.ColumnDouble targetAmount;

  late final _i1.ColumnDouble currentAmount;

  late final _i1.ColumnDateTime deadline;

  late final _i1.ColumnString status;

  late final _i1.ColumnBool isDefault;

  late final _i1.ColumnInt userProfileId;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnString notes;

  @override
  List<_i1.Column> get columns => [
    id,
    name,
    targetAmount,
    currentAmount,
    deadline,
    status,
    isDefault,
    userProfileId,
    createdAt,
    updatedAt,
    notes,
  ];
}

class GoalInclude extends _i1.IncludeObject {
  GoalInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => Goal.t;
}

class GoalIncludeList extends _i1.IncludeList {
  GoalIncludeList._({
    _i1.WhereExpressionBuilder<GoalTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Goal.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => Goal.t;
}

class GoalRepository {
  const GoalRepository._();

  /// Returns a list of [Goal]s matching the given query parameters.
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
  Future<List<Goal>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<GoalTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<GoalTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<GoalTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<Goal>(
      where: where?.call(Goal.t),
      orderBy: orderBy?.call(Goal.t),
      orderByList: orderByList?.call(Goal.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [Goal] matching the given query parameters.
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
  Future<Goal?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<GoalTable>? where,
    int? offset,
    _i1.OrderByBuilder<GoalTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<GoalTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<Goal>(
      where: where?.call(Goal.t),
      orderBy: orderBy?.call(Goal.t),
      orderByList: orderByList?.call(Goal.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [Goal] by its [id] or null if no such row exists.
  Future<Goal?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<Goal>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [Goal]s in the list and returns the inserted rows.
  ///
  /// The returned [Goal]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<Goal>> insert(
    _i1.Session session,
    List<Goal> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<Goal>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [Goal] and returns the inserted row.
  ///
  /// The returned [Goal] will have its `id` field set.
  Future<Goal> insertRow(
    _i1.Session session,
    Goal row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Goal>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [Goal]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<Goal>> update(
    _i1.Session session,
    List<Goal> rows, {
    _i1.ColumnSelections<GoalTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<Goal>(
      rows,
      columns: columns?.call(Goal.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Goal]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Goal> updateRow(
    _i1.Session session,
    Goal row, {
    _i1.ColumnSelections<GoalTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Goal>(
      row,
      columns: columns?.call(Goal.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Goal] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Goal?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<GoalUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Goal>(
      id,
      columnValues: columnValues(Goal.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Goal]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<Goal>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<GoalUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<GoalTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<GoalTable>? orderBy,
    _i1.OrderByListBuilder<GoalTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<Goal>(
      columnValues: columnValues(Goal.t.updateTable),
      where: where(Goal.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Goal.t),
      orderByList: orderByList?.call(Goal.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [Goal]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<Goal>> delete(
    _i1.Session session,
    List<Goal> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Goal>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [Goal].
  Future<Goal> deleteRow(
    _i1.Session session,
    Goal row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Goal>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<Goal>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<GoalTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<Goal>(
      where: where(Goal.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<GoalTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Goal>(
      where: where?.call(Goal.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
