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

/// AgentAction model for logging AI-triggered actions
abstract class AgentAction
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  AgentAction._({
    this.id,
    required this.userProfileId,
    required this.actionType,
    required this.parameters,
    required this.status,
    this.resultMessage,
    required this.createdAt,
    this.executedAt,
    this.relatedEntityId,
    this.relatedEntityType,
  });

  factory AgentAction({
    int? id,
    required int userProfileId,
    required String actionType,
    required String parameters,
    required String status,
    String? resultMessage,
    required DateTime createdAt,
    DateTime? executedAt,
    int? relatedEntityId,
    String? relatedEntityType,
  }) = _AgentActionImpl;

  factory AgentAction.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentAction(
      id: jsonSerialization['id'] as int?,
      userProfileId: jsonSerialization['userProfileId'] as int,
      actionType: jsonSerialization['actionType'] as String,
      parameters: jsonSerialization['parameters'] as String,
      status: jsonSerialization['status'] as String,
      resultMessage: jsonSerialization['resultMessage'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      executedAt: jsonSerialization['executedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['executedAt']),
      relatedEntityId: jsonSerialization['relatedEntityId'] as int?,
      relatedEntityType: jsonSerialization['relatedEntityType'] as String?,
    );
  }

  static final t = AgentActionTable();

  static const db = AgentActionRepository._();

  @override
  int? id;

  int userProfileId;

  String actionType;

  String parameters;

  String status;

  String? resultMessage;

  DateTime createdAt;

  DateTime? executedAt;

  int? relatedEntityId;

  String? relatedEntityType;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [AgentAction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentAction copyWith({
    int? id,
    int? userProfileId,
    String? actionType,
    String? parameters,
    String? status,
    String? resultMessage,
    DateTime? createdAt,
    DateTime? executedAt,
    int? relatedEntityId,
    String? relatedEntityType,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentAction',
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      'actionType': actionType,
      'parameters': parameters,
      'status': status,
      if (resultMessage != null) 'resultMessage': resultMessage,
      'createdAt': createdAt.toJson(),
      if (executedAt != null) 'executedAt': executedAt?.toJson(),
      if (relatedEntityId != null) 'relatedEntityId': relatedEntityId,
      if (relatedEntityType != null) 'relatedEntityType': relatedEntityType,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AgentAction',
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      'actionType': actionType,
      'parameters': parameters,
      'status': status,
      if (resultMessage != null) 'resultMessage': resultMessage,
      'createdAt': createdAt.toJson(),
      if (executedAt != null) 'executedAt': executedAt?.toJson(),
      if (relatedEntityId != null) 'relatedEntityId': relatedEntityId,
      if (relatedEntityType != null) 'relatedEntityType': relatedEntityType,
    };
  }

  static AgentActionInclude include() {
    return AgentActionInclude._();
  }

  static AgentActionIncludeList includeList({
    _i1.WhereExpressionBuilder<AgentActionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentActionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentActionTable>? orderByList,
    AgentActionInclude? include,
  }) {
    return AgentActionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentAction.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(AgentAction.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentActionImpl extends AgentAction {
  _AgentActionImpl({
    int? id,
    required int userProfileId,
    required String actionType,
    required String parameters,
    required String status,
    String? resultMessage,
    required DateTime createdAt,
    DateTime? executedAt,
    int? relatedEntityId,
    String? relatedEntityType,
  }) : super._(
         id: id,
         userProfileId: userProfileId,
         actionType: actionType,
         parameters: parameters,
         status: status,
         resultMessage: resultMessage,
         createdAt: createdAt,
         executedAt: executedAt,
         relatedEntityId: relatedEntityId,
         relatedEntityType: relatedEntityType,
       );

  /// Returns a shallow copy of this [AgentAction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentAction copyWith({
    Object? id = _Undefined,
    int? userProfileId,
    String? actionType,
    String? parameters,
    String? status,
    Object? resultMessage = _Undefined,
    DateTime? createdAt,
    Object? executedAt = _Undefined,
    Object? relatedEntityId = _Undefined,
    Object? relatedEntityType = _Undefined,
  }) {
    return AgentAction(
      id: id is int? ? id : this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      actionType: actionType ?? this.actionType,
      parameters: parameters ?? this.parameters,
      status: status ?? this.status,
      resultMessage: resultMessage is String?
          ? resultMessage
          : this.resultMessage,
      createdAt: createdAt ?? this.createdAt,
      executedAt: executedAt is DateTime? ? executedAt : this.executedAt,
      relatedEntityId: relatedEntityId is int?
          ? relatedEntityId
          : this.relatedEntityId,
      relatedEntityType: relatedEntityType is String?
          ? relatedEntityType
          : this.relatedEntityType,
    );
  }
}

class AgentActionUpdateTable extends _i1.UpdateTable<AgentActionTable> {
  AgentActionUpdateTable(super.table);

  _i1.ColumnValue<int, int> userProfileId(int value) => _i1.ColumnValue(
    table.userProfileId,
    value,
  );

  _i1.ColumnValue<String, String> actionType(String value) => _i1.ColumnValue(
    table.actionType,
    value,
  );

  _i1.ColumnValue<String, String> parameters(String value) => _i1.ColumnValue(
    table.parameters,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> resultMessage(String? value) =>
      _i1.ColumnValue(
        table.resultMessage,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> executedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.executedAt,
        value,
      );

  _i1.ColumnValue<int, int> relatedEntityId(int? value) => _i1.ColumnValue(
    table.relatedEntityId,
    value,
  );

  _i1.ColumnValue<String, String> relatedEntityType(String? value) =>
      _i1.ColumnValue(
        table.relatedEntityType,
        value,
      );
}

class AgentActionTable extends _i1.Table<int?> {
  AgentActionTable({super.tableRelation}) : super(tableName: 'agent_actions') {
    updateTable = AgentActionUpdateTable(this);
    userProfileId = _i1.ColumnInt(
      'userProfileId',
      this,
    );
    actionType = _i1.ColumnString(
      'actionType',
      this,
    );
    parameters = _i1.ColumnString(
      'parameters',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    resultMessage = _i1.ColumnString(
      'resultMessage',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    executedAt = _i1.ColumnDateTime(
      'executedAt',
      this,
    );
    relatedEntityId = _i1.ColumnInt(
      'relatedEntityId',
      this,
    );
    relatedEntityType = _i1.ColumnString(
      'relatedEntityType',
      this,
    );
  }

  late final AgentActionUpdateTable updateTable;

  late final _i1.ColumnInt userProfileId;

  late final _i1.ColumnString actionType;

  late final _i1.ColumnString parameters;

  late final _i1.ColumnString status;

  late final _i1.ColumnString resultMessage;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime executedAt;

  late final _i1.ColumnInt relatedEntityId;

  late final _i1.ColumnString relatedEntityType;

  @override
  List<_i1.Column> get columns => [
    id,
    userProfileId,
    actionType,
    parameters,
    status,
    resultMessage,
    createdAt,
    executedAt,
    relatedEntityId,
    relatedEntityType,
  ];
}

class AgentActionInclude extends _i1.IncludeObject {
  AgentActionInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => AgentAction.t;
}

class AgentActionIncludeList extends _i1.IncludeList {
  AgentActionIncludeList._({
    _i1.WhereExpressionBuilder<AgentActionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AgentAction.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => AgentAction.t;
}

class AgentActionRepository {
  const AgentActionRepository._();

  /// Returns a list of [AgentAction]s matching the given query parameters.
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
  Future<List<AgentAction>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<AgentActionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentActionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentActionTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<AgentAction>(
      where: where?.call(AgentAction.t),
      orderBy: orderBy?.call(AgentAction.t),
      orderByList: orderByList?.call(AgentAction.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [AgentAction] matching the given query parameters.
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
  Future<AgentAction?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<AgentActionTable>? where,
    int? offset,
    _i1.OrderByBuilder<AgentActionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentActionTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<AgentAction>(
      where: where?.call(AgentAction.t),
      orderBy: orderBy?.call(AgentAction.t),
      orderByList: orderByList?.call(AgentAction.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [AgentAction] by its [id] or null if no such row exists.
  Future<AgentAction?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<AgentAction>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [AgentAction]s in the list and returns the inserted rows.
  ///
  /// The returned [AgentAction]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<AgentAction>> insert(
    _i1.Session session,
    List<AgentAction> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<AgentAction>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [AgentAction] and returns the inserted row.
  ///
  /// The returned [AgentAction] will have its `id` field set.
  Future<AgentAction> insertRow(
    _i1.Session session,
    AgentAction row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<AgentAction>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [AgentAction]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<AgentAction>> update(
    _i1.Session session,
    List<AgentAction> rows, {
    _i1.ColumnSelections<AgentActionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<AgentAction>(
      rows,
      columns: columns?.call(AgentAction.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentAction]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AgentAction> updateRow(
    _i1.Session session,
    AgentAction row, {
    _i1.ColumnSelections<AgentActionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<AgentAction>(
      row,
      columns: columns?.call(AgentAction.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentAction] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AgentAction?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<AgentActionUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<AgentAction>(
      id,
      columnValues: columnValues(AgentAction.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AgentAction]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<AgentAction>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<AgentActionUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<AgentActionTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentActionTable>? orderBy,
    _i1.OrderByListBuilder<AgentActionTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<AgentAction>(
      columnValues: columnValues(AgentAction.t.updateTable),
      where: where(AgentAction.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentAction.t),
      orderByList: orderByList?.call(AgentAction.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [AgentAction]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<AgentAction>> delete(
    _i1.Session session,
    List<AgentAction> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<AgentAction>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [AgentAction].
  Future<AgentAction> deleteRow(
    _i1.Session session,
    AgentAction row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AgentAction>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<AgentAction>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<AgentActionTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<AgentAction>(
      where: where(AgentAction.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<AgentActionTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<AgentAction>(
      where: where?.call(AgentAction.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
