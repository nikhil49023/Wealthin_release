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
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i1;
import 'package:serverpod_client/serverpod_client.dart' as _i2;
import 'dart:async' as _i3;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i4;
import 'package:wealthin_client/src/protocol/transaction.dart' as _i5;
import 'package:wealthin_client/src/protocol/agent_action.dart' as _i6;
import 'package:wealthin_client/src/protocol/business_idea.dart' as _i7;
import 'package:wealthin_client/src/protocol/budget.dart' as _i8;
import 'package:wealthin_client/src/protocol/dashboard_data.dart' as _i9;
import 'package:wealthin_client/src/protocol/debt.dart' as _i10;
import 'package:wealthin_client/src/protocol/goal.dart' as _i11;
import 'package:wealthin_client/src/protocol/scheduled_payment.dart' as _i12;
import 'package:wealthin_client/src/protocol/user_profile.dart' as _i13;
import 'package:wealthin_client/src/protocol/greetings/greeting.dart' as _i14;
import 'protocol.dart' as _i15;

/// By extending [EmailIdpBaseEndpoint], the email identity provider endpoints
/// are made available on the server and enable the corresponding sign-in widget
/// on the client.
/// {@category Endpoint}
class EndpointEmailIdp extends _i1.EndpointEmailIdpBase {
  EndpointEmailIdp(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'emailIdp';

  /// Logs in the user and returns a new session.
  ///
  /// Throws an [EmailAccountLoginException] in case of errors, with reason:
  /// - [EmailAccountLoginExceptionReason.invalidCredentials] if the email or
  ///   password is incorrect.
  /// - [EmailAccountLoginExceptionReason.tooManyAttempts] if there have been
  ///   too many failed login attempts.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _i3.Future<_i4.AuthSuccess> login({
    required String email,
    required String password,
  }) => caller.callServerEndpoint<_i4.AuthSuccess>(
    'emailIdp',
    'login',
    {
      'email': email,
      'password': password,
    },
  );

  /// Starts the registration for a new user account with an email-based login
  /// associated to it.
  ///
  /// Upon successful completion of this method, an email will have been
  /// sent to [email] with a verification link, which the user must open to
  /// complete the registration.
  ///
  /// Always returns a account request ID, which can be used to complete the
  /// registration. If the email is already registered, the returned ID will not
  /// be valid.
  @override
  _i3.Future<_i2.UuidValue> startRegistration({required String email}) =>
      caller.callServerEndpoint<_i2.UuidValue>(
        'emailIdp',
        'startRegistration',
        {'email': email},
      );

  /// Verifies an account request code and returns a token
  /// that can be used to complete the account creation.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if no request exists
  ///   for the given [accountRequestId] or [verificationCode] is invalid.
  @override
  _i3.Future<String> verifyRegistrationCode({
    required _i2.UuidValue accountRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyRegistrationCode',
    {
      'accountRequestId': accountRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a new account registration, creating a new auth user with a
  /// profile and attaching the given email account to it.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if the [registrationToken]
  ///   is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  ///
  /// Returns a session for the newly created user.
  @override
  _i3.Future<_i4.AuthSuccess> finishRegistration({
    required String registrationToken,
    required String password,
  }) => caller.callServerEndpoint<_i4.AuthSuccess>(
    'emailIdp',
    'finishRegistration',
    {
      'registrationToken': registrationToken,
      'password': password,
    },
  );

  /// Requests a password reset for [email].
  ///
  /// If the email address is registered, an email with reset instructions will
  /// be send out. If the email is unknown, this method will have no effect.
  ///
  /// Always returns a password reset request ID, which can be used to complete
  /// the reset. If the email is not registered, the returned ID will not be
  /// valid.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to request a password reset.
  ///
  @override
  _i3.Future<_i2.UuidValue> startPasswordReset({required String email}) =>
      caller.callServerEndpoint<_i2.UuidValue>(
        'emailIdp',
        'startPasswordReset',
        {'email': email},
      );

  /// Verifies a password reset code and returns a finishPasswordResetToken
  /// that can be used to finish the password reset.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to verify the password reset.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// If multiple steps are required to complete the password reset, this endpoint
  /// should be overridden to return credentials for the next step instead
  /// of the credentials for setting the password.
  @override
  _i3.Future<String> verifyPasswordResetCode({
    required _i2.UuidValue passwordResetRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyPasswordResetCode',
    {
      'passwordResetRequestId': passwordResetRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a password reset request by setting a new password.
  ///
  /// The [verificationCode] returned from [verifyPasswordResetCode] is used to
  /// validate the password reset request.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.policyViolation] if the new
  ///   password does not comply with the password policy.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _i3.Future<void> finishPasswordReset({
    required String finishPasswordResetToken,
    required String newPassword,
  }) => caller.callServerEndpoint<void>(
    'emailIdp',
    'finishPasswordReset',
    {
      'finishPasswordResetToken': finishPasswordResetToken,
      'newPassword': newPassword,
    },
  );
}

/// By extending [RefreshJwtTokensEndpoint], the JWT token refresh endpoint
/// is made available on the server and enables automatic token refresh on the client.
/// {@category Endpoint}
class EndpointJwtRefresh extends _i4.EndpointRefreshJwtTokens {
  EndpointJwtRefresh(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'jwtRefresh';

  /// Creates a new token pair for the given [refreshToken].
  ///
  /// Can throw the following exceptions:
  /// -[RefreshTokenMalformedException]: refresh token is malformed and could
  ///   not be parsed. Not expected to happen for tokens issued by the server.
  /// -[RefreshTokenNotFoundException]: refresh token is unknown to the server.
  ///   Either the token was deleted or generated by a different server.
  /// -[RefreshTokenExpiredException]: refresh token has expired. Will happen
  ///   only if it has not been used within configured `refreshTokenLifetime`.
  /// -[RefreshTokenInvalidSecretException]: refresh token is incorrect, meaning
  ///   it does not refer to the current secret refresh token. This indicates
  ///   either a malfunctioning client or a malicious attempt by someone who has
  ///   obtained the refresh token. In this case the underlying refresh token
  ///   will be deleted, and access to it will expire fully when the last access
  ///   token is elapsed.
  ///
  /// This endpoint is unauthenticated, meaning the client won't include any
  /// authentication information with the call.
  @override
  _i3.Future<_i4.AuthSuccess> refreshAccessToken({
    required String refreshToken,
  }) => caller.callServerEndpoint<_i4.AuthSuccess>(
    'jwtRefresh',
    'refreshAccessToken',
    {'refreshToken': refreshToken},
    authenticated: false,
  );
}

/// AgentEndpoint: The brain of the agentic system.
/// Handles intent detection, tool calling, and action execution.
/// {@category Endpoint}
class EndpointAgent extends _i2.EndpointRef {
  EndpointAgent(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'agent';

  /// Main chat endpoint with function calling support
  _i3.Future<Map<String, dynamic>> chat(
    String userMessage, {
    int? userId,
    List<_i5.Transaction>? recentTransactions,
  }) => caller.callServerEndpoint<Map<String, dynamic>>(
    'agent',
    'chat',
    {
      'userMessage': userMessage,
      'userId': userId,
      'recentTransactions': recentTransactions,
    },
  );

  /// Execute a confirmed action
  _i3.Future<Map<String, dynamic>> executeAction(
    String actionType,
    String parametersJson,
    int userId,
  ) => caller.callServerEndpoint<Map<String, dynamic>>(
    'agent',
    'executeAction',
    {
      'actionType': actionType,
      'parametersJson': parametersJson,
      'userId': userId,
    },
  );

  /// Get pending AI actions for a user
  _i3.Future<List<_i6.AgentAction>> getPendingActions(int userId) =>
      caller.callServerEndpoint<List<_i6.AgentAction>>(
        'agent',
        'getPendingActions',
        {'userId': userId},
      );
}

/// AI Advisor Endpoint with smart routing between RAG and LLM
/// Now with tool/action capabilities for budgets, goals, transactions
/// {@category Endpoint}
class EndpointAiAdvisor extends _i2.EndpointRef {
  EndpointAiAdvisor(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'aiAdvisor';

  /// Smart query processor - routes to RAG/LLM or tools based on intent
  _i3.Future<String> askAdvisor(String query) =>
      caller.callServerEndpoint<String>(
        'aiAdvisor',
        'askAdvisor',
        {'query': query},
      );

  /// Process query with tools - explicitly uses function calling
  _i3.Future<String> askWithTools(String query) =>
      caller.callServerEndpoint<String>(
        'aiAdvisor',
        'askWithTools',
        {'query': query},
      );

  /// Get routing decision without executing (for debugging/UI)
  _i3.Future<Map<String, dynamic>> getRouteDecision(String query) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'aiAdvisor',
        'getRouteDecision',
        {'query': query},
      );

  /// Get available AI tools/actions
  _i3.Future<List<Map<String, dynamic>>> getAvailableTools() =>
      caller.callServerEndpoint<List<Map<String, dynamic>>>(
        'aiAdvisor',
        'getAvailableTools',
        {},
      );

  /// Ask advisor with structured response for action confirmation flow
  /// Returns full response with action data for UI to show confirmation cards
  _i3.Future<Map<String, dynamic>> askAdvisorStructured(String query) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'aiAdvisor',
        'askAdvisorStructured',
        {'query': query},
      );

  /// Preview an action without executing it - for confirmation flow
  _i3.Future<Map<String, dynamic>> previewAction(String query) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'aiAdvisor',
        'previewAction',
        {'query': query},
      );

  /// Execute a confirmed action
  _i3.Future<Map<String, dynamic>> confirmAction(
    String actionType,
    Map<String, dynamic> parameters,
  ) => caller.callServerEndpoint<Map<String, dynamic>>(
    'aiAdvisor',
    'confirmAction',
    {
      'actionType': actionType,
      'parameters': parameters,
    },
  );
}

/// {@category Endpoint}
class EndpointBrainstorm extends _i2.EndpointRef {
  EndpointBrainstorm(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'brainstorm';

  _i3.Future<_i7.BusinessIdea> analyzeIdea(String ideaDescription) =>
      caller.callServerEndpoint<_i7.BusinessIdea>(
        'brainstorm',
        'analyzeIdea',
        {'ideaDescription': ideaDescription},
      );
}

/// Budget Endpoint - CRUD operations for budgets
/// {@category Endpoint}
class EndpointBudget extends _i2.EndpointRef {
  EndpointBudget(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'budget';

  /// Get all budgets for a user
  _i3.Future<List<_i8.Budget>> getBudgets(int userProfileId) =>
      caller.callServerEndpoint<List<_i8.Budget>>(
        'budget',
        'getBudgets',
        {'userProfileId': userProfileId},
      );

  /// Create a new budget
  _i3.Future<_i8.Budget> createBudget(_i8.Budget budget) =>
      caller.callServerEndpoint<_i8.Budget>(
        'budget',
        'createBudget',
        {'budget': budget},
      );

  /// Update a budget
  _i3.Future<_i8.Budget> updateBudget(_i8.Budget budget) =>
      caller.callServerEndpoint<_i8.Budget>(
        'budget',
        'updateBudget',
        {'budget': budget},
      );

  /// Delete a budget
  _i3.Future<bool> deleteBudget(int budgetId) =>
      caller.callServerEndpoint<bool>(
        'budget',
        'deleteBudget',
        {'budgetId': budgetId},
      );

  /// Update budget spent amount based on transactions
  _i3.Future<void> recalculateBudgetSpending(int userProfileId) =>
      caller.callServerEndpoint<void>(
        'budget',
        'recalculateBudgetSpending',
        {'userProfileId': userProfileId},
      );
}

/// {@category Endpoint}
class EndpointDashboard extends _i2.EndpointRef {
  EndpointDashboard(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'dashboard';

  _i3.Future<_i9.DashboardData> getDashboardData() =>
      caller.callServerEndpoint<_i9.DashboardData>(
        'dashboard',
        'getDashboardData',
        {},
      );
}

/// DebtEndpoint: Manage loans, EMIs, and credit tracking
/// {@category Endpoint}
class EndpointDebt extends _i2.EndpointRef {
  EndpointDebt(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'debt';

  /// Get all debts for a user
  _i3.Future<List<_i10.Debt>> getDebts(int userId) =>
      caller.callServerEndpoint<List<_i10.Debt>>(
        'debt',
        'getDebts',
        {'userId': userId},
      );

  /// Get active debts only
  _i3.Future<List<_i10.Debt>> getActiveDebts(int userId) =>
      caller.callServerEndpoint<List<_i10.Debt>>(
        'debt',
        'getActiveDebts',
        {'userId': userId},
      );

  /// Create a new debt
  _i3.Future<_i10.Debt> createDebt(_i10.Debt debt) =>
      caller.callServerEndpoint<_i10.Debt>(
        'debt',
        'createDebt',
        {'debt': debt},
      );

  /// Update a debt
  _i3.Future<_i10.Debt> updateDebt(_i10.Debt debt) =>
      caller.callServerEndpoint<_i10.Debt>(
        'debt',
        'updateDebt',
        {'debt': debt},
      );

  /// Record a payment towards a debt
  _i3.Future<_i10.Debt> recordPayment(
    int debtId,
    double paymentAmount,
  ) => caller.callServerEndpoint<_i10.Debt>(
    'debt',
    'recordPayment',
    {
      'debtId': debtId,
      'paymentAmount': paymentAmount,
    },
  );

  /// Delete a debt
  _i3.Future<bool> deleteDebt(int debtId) => caller.callServerEndpoint<bool>(
    'debt',
    'deleteDebt',
    {'debtId': debtId},
  );

  /// Calculate EMI for a loan
  _i3.Future<Map<String, dynamic>> calculateEmi(
    double principal,
    double annualRate,
    int tenureMonths,
  ) => caller.callServerEndpoint<Map<String, dynamic>>(
    'debt',
    'calculateEmi',
    {
      'principal': principal,
      'annualRate': annualRate,
      'tenureMonths': tenureMonths,
    },
  );

  /// Get debt summary for a user
  _i3.Future<Map<String, dynamic>> getDebtSummary(int userId) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'debt',
        'getDebtSummary',
        {'userId': userId},
      );
}

/// Goal Endpoint - CRUD operations for savings goals
/// {@category Endpoint}
class EndpointGoal extends _i2.EndpointRef {
  EndpointGoal(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'goal';

  /// Get all goals for a user
  _i3.Future<List<_i11.Goal>> getGoals(int userProfileId) =>
      caller.callServerEndpoint<List<_i11.Goal>>(
        'goal',
        'getGoals',
        {'userProfileId': userProfileId},
      );

  /// Create a new goal
  _i3.Future<_i11.Goal> createGoal(_i11.Goal goal) =>
      caller.callServerEndpoint<_i11.Goal>(
        'goal',
        'createGoal',
        {'goal': goal},
      );

  /// Update a goal (e.g., add to currentAmount)
  _i3.Future<_i11.Goal> updateGoal(_i11.Goal goal) =>
      caller.callServerEndpoint<_i11.Goal>(
        'goal',
        'updateGoal',
        {'goal': goal},
      );

  /// Delete a goal
  _i3.Future<bool> deleteGoal(int goalId) => caller.callServerEndpoint<bool>(
    'goal',
    'deleteGoal',
    {'goalId': goalId},
  );

  /// Create default emergency fund goal for new users
  _i3.Future<_i11.Goal> createDefaultEmergencyFund(
    int userProfileId,
    double monthlyExpenses,
  ) => caller.callServerEndpoint<_i11.Goal>(
    'goal',
    'createDefaultEmergencyFund',
    {
      'userProfileId': userProfileId,
      'monthlyExpenses': monthlyExpenses,
    },
  );

  /// Calculate overall savings progress towards all goals
  _i3.Future<Map<String, dynamic>> getSavingsProgress(int userProfileId) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'goal',
        'getSavingsProgress',
        {'userProfileId': userProfileId},
      );
}

/// Investment Calculator Endpoint
/// Connects to Python sidecar for advanced financial calculations
/// {@category Endpoint}
class EndpointInvestment extends _i2.EndpointRef {
  EndpointInvestment(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'investment';

  /// Calculate SIP (Systematic Investment Plan) returns
  _i3.Future<Map<String, dynamic>> calculateSIP(
    double monthlyInvestment,
    double expectedRate,
    int durationMonths,
  ) => caller.callServerEndpoint<Map<String, dynamic>>(
    'investment',
    'calculateSIP',
    {
      'monthlyInvestment': monthlyInvestment,
      'expectedRate': expectedRate,
      'durationMonths': durationMonths,
    },
  );

  /// Calculate FD (Fixed Deposit) maturity
  _i3.Future<Map<String, dynamic>> calculateFD(
    double principal,
    double rate,
    int tenureMonths, {
    required String compounding,
  }) => caller.callServerEndpoint<Map<String, dynamic>>(
    'investment',
    'calculateFD',
    {
      'principal': principal,
      'rate': rate,
      'tenureMonths': tenureMonths,
      'compounding': compounding,
    },
  );

  /// Calculate EMI (Equated Monthly Installment)
  _i3.Future<Map<String, dynamic>> calculateEMI(
    double principal,
    double rate,
    int tenureMonths, {
    required bool includeAmortization,
  }) => caller.callServerEndpoint<Map<String, dynamic>>(
    'investment',
    'calculateEMI',
    {
      'principal': principal,
      'rate': rate,
      'tenureMonths': tenureMonths,
      'includeAmortization': includeAmortization,
    },
  );

  /// Calculate RD (Recurring Deposit) maturity
  _i3.Future<Map<String, dynamic>> calculateRD(
    double monthlyDeposit,
    double rate,
    int tenureMonths,
  ) => caller.callServerEndpoint<Map<String, dynamic>>(
    'investment',
    'calculateRD',
    {
      'monthlyDeposit': monthlyDeposit,
      'rate': rate,
      'tenureMonths': tenureMonths,
    },
  );

  /// Calculate required SIP for a goal
  _i3.Future<Map<String, dynamic>> calculateGoalSIP(
    double targetAmount,
    int durationMonths,
    double expectedRate,
  ) => caller.callServerEndpoint<Map<String, dynamic>>(
    'investment',
    'calculateGoalSIP',
    {
      'targetAmount': targetAmount,
      'durationMonths': durationMonths,
      'expectedRate': expectedRate,
    },
  );

  /// Calculate CAGR (Compound Annual Growth Rate)
  _i3.Future<Map<String, dynamic>> calculateCAGR(
    double initialValue,
    double finalValue,
    double years,
  ) => caller.callServerEndpoint<Map<String, dynamic>>(
    'investment',
    'calculateCAGR',
    {
      'initialValue': initialValue,
      'finalValue': finalValue,
      'years': years,
    },
  );
}

/// ScheduledPaymentEndpoint: Manage recurring payments and reminders
/// {@category Endpoint}
class EndpointScheduledPayment extends _i2.EndpointRef {
  EndpointScheduledPayment(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'scheduledPayment';

  /// Get all scheduled payments for a user
  _i3.Future<List<_i12.ScheduledPayment>> getScheduledPayments(int userId) =>
      caller.callServerEndpoint<List<_i12.ScheduledPayment>>(
        'scheduledPayment',
        'getScheduledPayments',
        {'userId': userId},
      );

  /// Get active scheduled payments only
  _i3.Future<List<_i12.ScheduledPayment>> getActivePayments(int userId) =>
      caller.callServerEndpoint<List<_i12.ScheduledPayment>>(
        'scheduledPayment',
        'getActivePayments',
        {'userId': userId},
      );

  /// Get upcoming payments (due within next 7 days)
  _i3.Future<List<_i12.ScheduledPayment>> getUpcomingPayments(int userId) =>
      caller.callServerEndpoint<List<_i12.ScheduledPayment>>(
        'scheduledPayment',
        'getUpcomingPayments',
        {'userId': userId},
      );

  /// Get overdue payments
  _i3.Future<List<_i12.ScheduledPayment>> getOverduePayments(int userId) =>
      caller.callServerEndpoint<List<_i12.ScheduledPayment>>(
        'scheduledPayment',
        'getOverduePayments',
        {'userId': userId},
      );

  /// Create a new scheduled payment
  _i3.Future<_i12.ScheduledPayment> createPayment(
    _i12.ScheduledPayment payment,
  ) => caller.callServerEndpoint<_i12.ScheduledPayment>(
    'scheduledPayment',
    'createPayment',
    {'payment': payment},
  );

  /// Update a scheduled payment
  _i3.Future<_i12.ScheduledPayment> updatePayment(
    _i12.ScheduledPayment payment,
  ) => caller.callServerEndpoint<_i12.ScheduledPayment>(
    'scheduledPayment',
    'updatePayment',
    {'payment': payment},
  );

  /// Mark a payment as paid and calculate next due date
  _i3.Future<_i12.ScheduledPayment> markAsPaid(int paymentId) =>
      caller.callServerEndpoint<_i12.ScheduledPayment>(
        'scheduledPayment',
        'markAsPaid',
        {'paymentId': paymentId},
      );

  /// Toggle payment active status
  _i3.Future<_i12.ScheduledPayment> toggleActive(int paymentId) =>
      caller.callServerEndpoint<_i12.ScheduledPayment>(
        'scheduledPayment',
        'toggleActive',
        {'paymentId': paymentId},
      );

  /// Delete a scheduled payment
  _i3.Future<bool> deletePayment(int paymentId) =>
      caller.callServerEndpoint<bool>(
        'scheduledPayment',
        'deletePayment',
        {'paymentId': paymentId},
      );

  /// Get payment summary for a user
  _i3.Future<Map<String, dynamic>> getPaymentSummary(int userId) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'scheduledPayment',
        'getPaymentSummary',
        {'userId': userId},
      );
}

/// {@category Endpoint}
class EndpointTransaction extends _i2.EndpointRef {
  EndpointTransaction(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'transaction';

  _i3.Future<List<_i5.Transaction>> getTransactions({String? type}) =>
      caller.callServerEndpoint<List<_i5.Transaction>>(
        'transaction',
        'getTransactions',
        {'type': type},
      );

  _i3.Future<void> addTransaction(_i5.Transaction transaction) =>
      caller.callServerEndpoint<void>(
        'transaction',
        'addTransaction',
        {'transaction': transaction},
      );
}

/// TransactionImportEndpoint: Handle document-based transaction imports
/// Supports: Vision (handwritten/bills), PDF extraction, Bank statements
/// {@category Endpoint}
class EndpointTransactionImport extends _i2.EndpointRef {
  EndpointTransactionImport(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'transactionImport';

  /// Extract transactions from an image using Vision model (for handwritten/bills)
  _i3.Future<Map<String, dynamic>> extractFromImage(
    String imageBase64,
    String mimeType,
    int userId,
  ) => caller.callServerEndpoint<Map<String, dynamic>>(
    'transactionImport',
    'extractFromImage',
    {
      'imageBase64': imageBase64,
      'mimeType': mimeType,
      'userId': userId,
    },
  );

  /// Extract transactions from a PDF using Python sidecar
  _i3.Future<Map<String, dynamic>> extractFromPdf(
    String pdfBase64,
    int userId,
  ) => caller.callServerEndpoint<Map<String, dynamic>>(
    'transactionImport',
    'extractFromPdf',
    {
      'pdfBase64': pdfBase64,
      'userId': userId,
    },
  );

  /// Import extracted transactions to database
  _i3.Future<Map<String, dynamic>> importTransactions(
    List<Map<String, dynamic>> transactionData,
    int userId,
  ) => caller.callServerEndpoint<Map<String, dynamic>>(
    'transactionImport',
    'importTransactions',
    {
      'transactionData': transactionData,
      'userId': userId,
    },
  );

  /// Get import history for a user
  _i3.Future<Map<String, dynamic>> getImportStats(int userId) =>
      caller.callServerEndpoint<Map<String, dynamic>>(
        'transactionImport',
        'getImportStats',
        {'userId': userId},
      );
}

/// UserProfile Endpoint - User management and gamification
/// {@category Endpoint}
class EndpointUserProfile extends _i2.EndpointRef {
  EndpointUserProfile(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'userProfile';

  /// Get or create user profile
  _i3.Future<_i13.UserProfile> getOrCreateProfile(String uid) =>
      caller.callServerEndpoint<_i13.UserProfile>(
        'userProfile',
        'getOrCreateProfile',
        {'uid': uid},
      );

  /// Award credits to user
  _i3.Future<_i13.UserProfile> awardCredits(
    int userProfileId,
    int amount,
    String reason,
  ) => caller.callServerEndpoint<_i13.UserProfile>(
    'userProfile',
    'awardCredits',
    {
      'userProfileId': userProfileId,
      'amount': amount,
      'reason': reason,
    },
  );

  /// Mark a goal as completed
  _i3.Future<_i13.UserProfile> markGoalCompleted(
    int userProfileId,
    int goalId,
  ) => caller.callServerEndpoint<_i13.UserProfile>(
    'userProfile',
    'markGoalCompleted',
    {
      'userProfileId': userProfileId,
      'goalId': goalId,
    },
  );

  /// Get user's credit balance
  _i3.Future<int> getCreditBalance(int userProfileId) =>
      caller.callServerEndpoint<int>(
        'userProfile',
        'getCreditBalance',
        {'userProfileId': userProfileId},
      );

  /// Check and award savings rate bonus (if rate >= 60%)
  _i3.Future<bool> checkAndAwardSavingsBonus(
    int userProfileId,
    int savingsRate,
  ) => caller.callServerEndpoint<bool>(
    'userProfile',
    'checkAndAwardSavingsBonus',
    {
      'userProfileId': userProfileId,
      'savingsRate': savingsRate,
    },
  );
}

/// This is an example endpoint that returns a greeting message through
/// its [hello] method.
/// {@category Endpoint}
class EndpointGreeting extends _i2.EndpointRef {
  EndpointGreeting(_i2.EndpointCaller caller) : super(caller);

  @override
  String get name => 'greeting';

  /// Returns a personalized greeting message: "Hello {name}".
  _i3.Future<_i14.Greeting> hello(String name) =>
      caller.callServerEndpoint<_i14.Greeting>(
        'greeting',
        'hello',
        {'name': name},
      );
}

class Modules {
  Modules(Client client) {
    serverpod_auth_idp = _i1.Caller(client);
    serverpod_auth_core = _i4.Caller(client);
  }

  late final _i1.Caller serverpod_auth_idp;

  late final _i4.Caller serverpod_auth_core;
}

class Client extends _i2.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    @Deprecated(
      'Use authKeyProvider instead. This will be removed in future releases.',
    )
    super.authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _i2.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_i2.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i15.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    emailIdp = EndpointEmailIdp(this);
    jwtRefresh = EndpointJwtRefresh(this);
    agent = EndpointAgent(this);
    aiAdvisor = EndpointAiAdvisor(this);
    brainstorm = EndpointBrainstorm(this);
    budget = EndpointBudget(this);
    dashboard = EndpointDashboard(this);
    debt = EndpointDebt(this);
    goal = EndpointGoal(this);
    investment = EndpointInvestment(this);
    scheduledPayment = EndpointScheduledPayment(this);
    transaction = EndpointTransaction(this);
    transactionImport = EndpointTransactionImport(this);
    userProfile = EndpointUserProfile(this);
    greeting = EndpointGreeting(this);
    modules = Modules(this);
  }

  late final EndpointEmailIdp emailIdp;

  late final EndpointJwtRefresh jwtRefresh;

  late final EndpointAgent agent;

  late final EndpointAiAdvisor aiAdvisor;

  late final EndpointBrainstorm brainstorm;

  late final EndpointBudget budget;

  late final EndpointDashboard dashboard;

  late final EndpointDebt debt;

  late final EndpointGoal goal;

  late final EndpointInvestment investment;

  late final EndpointScheduledPayment scheduledPayment;

  late final EndpointTransaction transaction;

  late final EndpointTransactionImport transactionImport;

  late final EndpointUserProfile userProfile;

  late final EndpointGreeting greeting;

  late final Modules modules;

  @override
  Map<String, _i2.EndpointRef> get endpointRefLookup => {
    'emailIdp': emailIdp,
    'jwtRefresh': jwtRefresh,
    'agent': agent,
    'aiAdvisor': aiAdvisor,
    'brainstorm': brainstorm,
    'budget': budget,
    'dashboard': dashboard,
    'debt': debt,
    'goal': goal,
    'investment': investment,
    'scheduledPayment': scheduledPayment,
    'transaction': transaction,
    'transactionImport': transactionImport,
    'userProfile': userProfile,
    'greeting': greeting,
  };

  @override
  Map<String, _i2.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_idp': modules.serverpod_auth_idp,
    'serverpod_auth_core': modules.serverpod_auth_core,
  };
}
