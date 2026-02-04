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
import '../auth/email_idp_endpoint.dart' as _i2;
import '../auth/jwt_refresh_endpoint.dart' as _i3;
import '../endpoints/agent_endpoint.dart' as _i4;
import '../endpoints/ai_advisor_endpoint.dart' as _i5;
import '../endpoints/brainstorm_endpoint.dart' as _i6;
import '../endpoints/budget_endpoint.dart' as _i7;
import '../endpoints/dashboard_endpoint.dart' as _i8;
import '../endpoints/debt_endpoint.dart' as _i9;
import '../endpoints/goal_endpoint.dart' as _i10;
import '../endpoints/investment_endpoint.dart' as _i11;
import '../endpoints/scheduled_payment_endpoint.dart' as _i12;
import '../endpoints/transaction_endpoint.dart' as _i13;
import '../endpoints/transaction_import_endpoint.dart' as _i14;
import '../endpoints/user_profile_endpoint.dart' as _i15;
import '../greetings/greeting_endpoint.dart' as _i16;
import 'package:wealthin_server/src/generated/transaction.dart' as _i17;
import 'package:wealthin_server/src/generated/budget.dart' as _i18;
import 'package:wealthin_server/src/generated/debt.dart' as _i19;
import 'package:wealthin_server/src/generated/goal.dart' as _i20;
import 'package:wealthin_server/src/generated/scheduled_payment.dart' as _i21;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _i22;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _i23;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'emailIdp': _i2.EmailIdpEndpoint()
        ..initialize(
          server,
          'emailIdp',
          null,
        ),
      'jwtRefresh': _i3.JwtRefreshEndpoint()
        ..initialize(
          server,
          'jwtRefresh',
          null,
        ),
      'agent': _i4.AgentEndpoint()
        ..initialize(
          server,
          'agent',
          null,
        ),
      'aiAdvisor': _i5.AiAdvisorEndpoint()
        ..initialize(
          server,
          'aiAdvisor',
          null,
        ),
      'brainstorm': _i6.BrainstormEndpoint()
        ..initialize(
          server,
          'brainstorm',
          null,
        ),
      'budget': _i7.BudgetEndpoint()
        ..initialize(
          server,
          'budget',
          null,
        ),
      'dashboard': _i8.DashboardEndpoint()
        ..initialize(
          server,
          'dashboard',
          null,
        ),
      'debt': _i9.DebtEndpoint()
        ..initialize(
          server,
          'debt',
          null,
        ),
      'goal': _i10.GoalEndpoint()
        ..initialize(
          server,
          'goal',
          null,
        ),
      'investment': _i11.InvestmentEndpoint()
        ..initialize(
          server,
          'investment',
          null,
        ),
      'scheduledPayment': _i12.ScheduledPaymentEndpoint()
        ..initialize(
          server,
          'scheduledPayment',
          null,
        ),
      'transaction': _i13.TransactionEndpoint()
        ..initialize(
          server,
          'transaction',
          null,
        ),
      'transactionImport': _i14.TransactionImportEndpoint()
        ..initialize(
          server,
          'transactionImport',
          null,
        ),
      'userProfile': _i15.UserProfileEndpoint()
        ..initialize(
          server,
          'userProfile',
          null,
        ),
      'greeting': _i16.GreetingEndpoint()
        ..initialize(
          server,
          'greeting',
          null,
        ),
    };
    connectors['emailIdp'] = _i1.EndpointConnector(
      name: 'emailIdp',
      endpoint: endpoints['emailIdp']!,
      methodConnectors: {
        'login': _i1.MethodConnector(
          name: 'login',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'password': _i1.ParameterDescription(
              name: 'password',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i2.EmailIdpEndpoint).login(
                session,
                email: params['email'],
                password: params['password'],
              ),
        ),
        'startRegistration': _i1.MethodConnector(
          name: 'startRegistration',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i2.EmailIdpEndpoint)
                  .startRegistration(
                    session,
                    email: params['email'],
                  ),
        ),
        'verifyRegistrationCode': _i1.MethodConnector(
          name: 'verifyRegistrationCode',
          params: {
            'accountRequestId': _i1.ParameterDescription(
              name: 'accountRequestId',
              type: _i1.getType<_i1.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _i1.ParameterDescription(
              name: 'verificationCode',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i2.EmailIdpEndpoint)
                  .verifyRegistrationCode(
                    session,
                    accountRequestId: params['accountRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishRegistration': _i1.MethodConnector(
          name: 'finishRegistration',
          params: {
            'registrationToken': _i1.ParameterDescription(
              name: 'registrationToken',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'password': _i1.ParameterDescription(
              name: 'password',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i2.EmailIdpEndpoint)
                  .finishRegistration(
                    session,
                    registrationToken: params['registrationToken'],
                    password: params['password'],
                  ),
        ),
        'startPasswordReset': _i1.MethodConnector(
          name: 'startPasswordReset',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i2.EmailIdpEndpoint)
                  .startPasswordReset(
                    session,
                    email: params['email'],
                  ),
        ),
        'verifyPasswordResetCode': _i1.MethodConnector(
          name: 'verifyPasswordResetCode',
          params: {
            'passwordResetRequestId': _i1.ParameterDescription(
              name: 'passwordResetRequestId',
              type: _i1.getType<_i1.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _i1.ParameterDescription(
              name: 'verificationCode',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i2.EmailIdpEndpoint)
                  .verifyPasswordResetCode(
                    session,
                    passwordResetRequestId: params['passwordResetRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishPasswordReset': _i1.MethodConnector(
          name: 'finishPasswordReset',
          params: {
            'finishPasswordResetToken': _i1.ParameterDescription(
              name: 'finishPasswordResetToken',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'newPassword': _i1.ParameterDescription(
              name: 'newPassword',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i2.EmailIdpEndpoint)
                  .finishPasswordReset(
                    session,
                    finishPasswordResetToken:
                        params['finishPasswordResetToken'],
                    newPassword: params['newPassword'],
                  ),
        ),
      },
    );
    connectors['jwtRefresh'] = _i1.EndpointConnector(
      name: 'jwtRefresh',
      endpoint: endpoints['jwtRefresh']!,
      methodConnectors: {
        'refreshAccessToken': _i1.MethodConnector(
          name: 'refreshAccessToken',
          params: {
            'refreshToken': _i1.ParameterDescription(
              name: 'refreshToken',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['jwtRefresh'] as _i3.JwtRefreshEndpoint)
                  .refreshAccessToken(
                    session,
                    refreshToken: params['refreshToken'],
                  ),
        ),
      },
    );
    connectors['agent'] = _i1.EndpointConnector(
      name: 'agent',
      endpoint: endpoints['agent']!,
      methodConnectors: {
        'chat': _i1.MethodConnector(
          name: 'chat',
          params: {
            'userMessage': _i1.ParameterDescription(
              name: 'userMessage',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
            'recentTransactions': _i1.ParameterDescription(
              name: 'recentTransactions',
              type: _i1.getType<List<_i17.Transaction>?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['agent'] as _i4.AgentEndpoint).chat(
                session,
                params['userMessage'],
                userId: params['userId'],
                recentTransactions: params['recentTransactions'],
              ),
        ),
        'executeAction': _i1.MethodConnector(
          name: 'executeAction',
          params: {
            'actionType': _i1.ParameterDescription(
              name: 'actionType',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'parametersJson': _i1.ParameterDescription(
              name: 'parametersJson',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['agent'] as _i4.AgentEndpoint).executeAction(
                    session,
                    params['actionType'],
                    params['parametersJson'],
                    params['userId'],
                  ),
        ),
        'getPendingActions': _i1.MethodConnector(
          name: 'getPendingActions',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['agent'] as _i4.AgentEndpoint).getPendingActions(
                    session,
                    params['userId'],
                  ),
        ),
      },
    );
    connectors['aiAdvisor'] = _i1.EndpointConnector(
      name: 'aiAdvisor',
      endpoint: endpoints['aiAdvisor']!,
      methodConnectors: {
        'askAdvisor': _i1.MethodConnector(
          name: 'askAdvisor',
          params: {
            'query': _i1.ParameterDescription(
              name: 'query',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['aiAdvisor'] as _i5.AiAdvisorEndpoint).askAdvisor(
                    session,
                    params['query'],
                  ),
        ),
        'askWithTools': _i1.MethodConnector(
          name: 'askWithTools',
          params: {
            'query': _i1.ParameterDescription(
              name: 'query',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['aiAdvisor'] as _i5.AiAdvisorEndpoint)
                  .askWithTools(
                    session,
                    params['query'],
                  ),
        ),
        'getRouteDecision': _i1.MethodConnector(
          name: 'getRouteDecision',
          params: {
            'query': _i1.ParameterDescription(
              name: 'query',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['aiAdvisor'] as _i5.AiAdvisorEndpoint)
                  .getRouteDecision(
                    session,
                    params['query'],
                  ),
        ),
        'getAvailableTools': _i1.MethodConnector(
          name: 'getAvailableTools',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['aiAdvisor'] as _i5.AiAdvisorEndpoint)
                  .getAvailableTools(session),
        ),
        'askAdvisorStructured': _i1.MethodConnector(
          name: 'askAdvisorStructured',
          params: {
            'query': _i1.ParameterDescription(
              name: 'query',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['aiAdvisor'] as _i5.AiAdvisorEndpoint)
                  .askAdvisorStructured(
                    session,
                    params['query'],
                  ),
        ),
        'previewAction': _i1.MethodConnector(
          name: 'previewAction',
          params: {
            'query': _i1.ParameterDescription(
              name: 'query',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['aiAdvisor'] as _i5.AiAdvisorEndpoint)
                  .previewAction(
                    session,
                    params['query'],
                  ),
        ),
        'confirmAction': _i1.MethodConnector(
          name: 'confirmAction',
          params: {
            'actionType': _i1.ParameterDescription(
              name: 'actionType',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'parameters': _i1.ParameterDescription(
              name: 'parameters',
              type: _i1.getType<Map<String, dynamic>>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['aiAdvisor'] as _i5.AiAdvisorEndpoint)
                  .confirmAction(
                    session,
                    params['actionType'],
                    params['parameters'],
                  ),
        ),
      },
    );
    connectors['brainstorm'] = _i1.EndpointConnector(
      name: 'brainstorm',
      endpoint: endpoints['brainstorm']!,
      methodConnectors: {
        'analyzeIdea': _i1.MethodConnector(
          name: 'analyzeIdea',
          params: {
            'ideaDescription': _i1.ParameterDescription(
              name: 'ideaDescription',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['brainstorm'] as _i6.BrainstormEndpoint)
                  .analyzeIdea(
                    session,
                    params['ideaDescription'],
                  ),
        ),
      },
    );
    connectors['budget'] = _i1.EndpointConnector(
      name: 'budget',
      endpoint: endpoints['budget']!,
      methodConnectors: {
        'getBudgets': _i1.MethodConnector(
          name: 'getBudgets',
          params: {
            'userProfileId': _i1.ParameterDescription(
              name: 'userProfileId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['budget'] as _i7.BudgetEndpoint).getBudgets(
                session,
                params['userProfileId'],
              ),
        ),
        'createBudget': _i1.MethodConnector(
          name: 'createBudget',
          params: {
            'budget': _i1.ParameterDescription(
              name: 'budget',
              type: _i1.getType<_i18.Budget>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['budget'] as _i7.BudgetEndpoint).createBudget(
                    session,
                    params['budget'],
                  ),
        ),
        'updateBudget': _i1.MethodConnector(
          name: 'updateBudget',
          params: {
            'budget': _i1.ParameterDescription(
              name: 'budget',
              type: _i1.getType<_i18.Budget>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['budget'] as _i7.BudgetEndpoint).updateBudget(
                    session,
                    params['budget'],
                  ),
        ),
        'deleteBudget': _i1.MethodConnector(
          name: 'deleteBudget',
          params: {
            'budgetId': _i1.ParameterDescription(
              name: 'budgetId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['budget'] as _i7.BudgetEndpoint).deleteBudget(
                    session,
                    params['budgetId'],
                  ),
        ),
        'recalculateBudgetSpending': _i1.MethodConnector(
          name: 'recalculateBudgetSpending',
          params: {
            'userProfileId': _i1.ParameterDescription(
              name: 'userProfileId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['budget'] as _i7.BudgetEndpoint)
                  .recalculateBudgetSpending(
                    session,
                    params['userProfileId'],
                  ),
        ),
      },
    );
    connectors['dashboard'] = _i1.EndpointConnector(
      name: 'dashboard',
      endpoint: endpoints['dashboard']!,
      methodConnectors: {
        'getDashboardData': _i1.MethodConnector(
          name: 'getDashboardData',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['dashboard'] as _i8.DashboardEndpoint)
                  .getDashboardData(session),
        ),
      },
    );
    connectors['debt'] = _i1.EndpointConnector(
      name: 'debt',
      endpoint: endpoints['debt']!,
      methodConnectors: {
        'getDebts': _i1.MethodConnector(
          name: 'getDebts',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['debt'] as _i9.DebtEndpoint).getDebts(
                session,
                params['userId'],
              ),
        ),
        'getActiveDebts': _i1.MethodConnector(
          name: 'getActiveDebts',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['debt'] as _i9.DebtEndpoint).getActiveDebts(
                session,
                params['userId'],
              ),
        ),
        'createDebt': _i1.MethodConnector(
          name: 'createDebt',
          params: {
            'debt': _i1.ParameterDescription(
              name: 'debt',
              type: _i1.getType<_i19.Debt>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['debt'] as _i9.DebtEndpoint).createDebt(
                session,
                params['debt'],
              ),
        ),
        'updateDebt': _i1.MethodConnector(
          name: 'updateDebt',
          params: {
            'debt': _i1.ParameterDescription(
              name: 'debt',
              type: _i1.getType<_i19.Debt>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['debt'] as _i9.DebtEndpoint).updateDebt(
                session,
                params['debt'],
              ),
        ),
        'recordPayment': _i1.MethodConnector(
          name: 'recordPayment',
          params: {
            'debtId': _i1.ParameterDescription(
              name: 'debtId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'paymentAmount': _i1.ParameterDescription(
              name: 'paymentAmount',
              type: _i1.getType<double>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['debt'] as _i9.DebtEndpoint).recordPayment(
                session,
                params['debtId'],
                params['paymentAmount'],
              ),
        ),
        'deleteDebt': _i1.MethodConnector(
          name: 'deleteDebt',
          params: {
            'debtId': _i1.ParameterDescription(
              name: 'debtId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['debt'] as _i9.DebtEndpoint).deleteDebt(
                session,
                params['debtId'],
              ),
        ),
        'calculateEmi': _i1.MethodConnector(
          name: 'calculateEmi',
          params: {
            'principal': _i1.ParameterDescription(
              name: 'principal',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'annualRate': _i1.ParameterDescription(
              name: 'annualRate',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'tenureMonths': _i1.ParameterDescription(
              name: 'tenureMonths',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['debt'] as _i9.DebtEndpoint).calculateEmi(
                session,
                params['principal'],
                params['annualRate'],
                params['tenureMonths'],
              ),
        ),
        'getDebtSummary': _i1.MethodConnector(
          name: 'getDebtSummary',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['debt'] as _i9.DebtEndpoint).getDebtSummary(
                session,
                params['userId'],
              ),
        ),
      },
    );
    connectors['goal'] = _i1.EndpointConnector(
      name: 'goal',
      endpoint: endpoints['goal']!,
      methodConnectors: {
        'getGoals': _i1.MethodConnector(
          name: 'getGoals',
          params: {
            'userProfileId': _i1.ParameterDescription(
              name: 'userProfileId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['goal'] as _i10.GoalEndpoint).getGoals(
                session,
                params['userProfileId'],
              ),
        ),
        'createGoal': _i1.MethodConnector(
          name: 'createGoal',
          params: {
            'goal': _i1.ParameterDescription(
              name: 'goal',
              type: _i1.getType<_i20.Goal>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['goal'] as _i10.GoalEndpoint).createGoal(
                session,
                params['goal'],
              ),
        ),
        'updateGoal': _i1.MethodConnector(
          name: 'updateGoal',
          params: {
            'goal': _i1.ParameterDescription(
              name: 'goal',
              type: _i1.getType<_i20.Goal>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['goal'] as _i10.GoalEndpoint).updateGoal(
                session,
                params['goal'],
              ),
        ),
        'deleteGoal': _i1.MethodConnector(
          name: 'deleteGoal',
          params: {
            'goalId': _i1.ParameterDescription(
              name: 'goalId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['goal'] as _i10.GoalEndpoint).deleteGoal(
                session,
                params['goalId'],
              ),
        ),
        'createDefaultEmergencyFund': _i1.MethodConnector(
          name: 'createDefaultEmergencyFund',
          params: {
            'userProfileId': _i1.ParameterDescription(
              name: 'userProfileId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'monthlyExpenses': _i1.ParameterDescription(
              name: 'monthlyExpenses',
              type: _i1.getType<double>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['goal'] as _i10.GoalEndpoint)
                  .createDefaultEmergencyFund(
                    session,
                    params['userProfileId'],
                    params['monthlyExpenses'],
                  ),
        ),
        'getSavingsProgress': _i1.MethodConnector(
          name: 'getSavingsProgress',
          params: {
            'userProfileId': _i1.ParameterDescription(
              name: 'userProfileId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['goal'] as _i10.GoalEndpoint).getSavingsProgress(
                    session,
                    params['userProfileId'],
                  ),
        ),
      },
    );
    connectors['investment'] = _i1.EndpointConnector(
      name: 'investment',
      endpoint: endpoints['investment']!,
      methodConnectors: {
        'calculateSIP': _i1.MethodConnector(
          name: 'calculateSIP',
          params: {
            'monthlyInvestment': _i1.ParameterDescription(
              name: 'monthlyInvestment',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'expectedRate': _i1.ParameterDescription(
              name: 'expectedRate',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'durationMonths': _i1.ParameterDescription(
              name: 'durationMonths',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['investment'] as _i11.InvestmentEndpoint)
                  .calculateSIP(
                    session,
                    params['monthlyInvestment'],
                    params['expectedRate'],
                    params['durationMonths'],
                  ),
        ),
        'calculateFD': _i1.MethodConnector(
          name: 'calculateFD',
          params: {
            'principal': _i1.ParameterDescription(
              name: 'principal',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'rate': _i1.ParameterDescription(
              name: 'rate',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'tenureMonths': _i1.ParameterDescription(
              name: 'tenureMonths',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'compounding': _i1.ParameterDescription(
              name: 'compounding',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['investment'] as _i11.InvestmentEndpoint)
                  .calculateFD(
                    session,
                    params['principal'],
                    params['rate'],
                    params['tenureMonths'],
                    compounding: params['compounding'],
                  ),
        ),
        'calculateEMI': _i1.MethodConnector(
          name: 'calculateEMI',
          params: {
            'principal': _i1.ParameterDescription(
              name: 'principal',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'rate': _i1.ParameterDescription(
              name: 'rate',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'tenureMonths': _i1.ParameterDescription(
              name: 'tenureMonths',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'includeAmortization': _i1.ParameterDescription(
              name: 'includeAmortization',
              type: _i1.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['investment'] as _i11.InvestmentEndpoint)
                  .calculateEMI(
                    session,
                    params['principal'],
                    params['rate'],
                    params['tenureMonths'],
                    includeAmortization: params['includeAmortization'],
                  ),
        ),
        'calculateRD': _i1.MethodConnector(
          name: 'calculateRD',
          params: {
            'monthlyDeposit': _i1.ParameterDescription(
              name: 'monthlyDeposit',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'rate': _i1.ParameterDescription(
              name: 'rate',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'tenureMonths': _i1.ParameterDescription(
              name: 'tenureMonths',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['investment'] as _i11.InvestmentEndpoint)
                  .calculateRD(
                    session,
                    params['monthlyDeposit'],
                    params['rate'],
                    params['tenureMonths'],
                  ),
        ),
        'calculateGoalSIP': _i1.MethodConnector(
          name: 'calculateGoalSIP',
          params: {
            'targetAmount': _i1.ParameterDescription(
              name: 'targetAmount',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'durationMonths': _i1.ParameterDescription(
              name: 'durationMonths',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'expectedRate': _i1.ParameterDescription(
              name: 'expectedRate',
              type: _i1.getType<double>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['investment'] as _i11.InvestmentEndpoint)
                  .calculateGoalSIP(
                    session,
                    params['targetAmount'],
                    params['durationMonths'],
                    params['expectedRate'],
                  ),
        ),
        'calculateCAGR': _i1.MethodConnector(
          name: 'calculateCAGR',
          params: {
            'initialValue': _i1.ParameterDescription(
              name: 'initialValue',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'finalValue': _i1.ParameterDescription(
              name: 'finalValue',
              type: _i1.getType<double>(),
              nullable: false,
            ),
            'years': _i1.ParameterDescription(
              name: 'years',
              type: _i1.getType<double>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['investment'] as _i11.InvestmentEndpoint)
                  .calculateCAGR(
                    session,
                    params['initialValue'],
                    params['finalValue'],
                    params['years'],
                  ),
        ),
      },
    );
    connectors['scheduledPayment'] = _i1.EndpointConnector(
      name: 'scheduledPayment',
      endpoint: endpoints['scheduledPayment']!,
      methodConnectors: {
        'getScheduledPayments': _i1.MethodConnector(
          name: 'getScheduledPayments',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['scheduledPayment']
                          as _i12.ScheduledPaymentEndpoint)
                      .getScheduledPayments(
                        session,
                        params['userId'],
                      ),
        ),
        'getActivePayments': _i1.MethodConnector(
          name: 'getActivePayments',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['scheduledPayment']
                          as _i12.ScheduledPaymentEndpoint)
                      .getActivePayments(
                        session,
                        params['userId'],
                      ),
        ),
        'getUpcomingPayments': _i1.MethodConnector(
          name: 'getUpcomingPayments',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['scheduledPayment']
                          as _i12.ScheduledPaymentEndpoint)
                      .getUpcomingPayments(
                        session,
                        params['userId'],
                      ),
        ),
        'getOverduePayments': _i1.MethodConnector(
          name: 'getOverduePayments',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['scheduledPayment']
                          as _i12.ScheduledPaymentEndpoint)
                      .getOverduePayments(
                        session,
                        params['userId'],
                      ),
        ),
        'createPayment': _i1.MethodConnector(
          name: 'createPayment',
          params: {
            'payment': _i1.ParameterDescription(
              name: 'payment',
              type: _i1.getType<_i21.ScheduledPayment>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['scheduledPayment']
                          as _i12.ScheduledPaymentEndpoint)
                      .createPayment(
                        session,
                        params['payment'],
                      ),
        ),
        'updatePayment': _i1.MethodConnector(
          name: 'updatePayment',
          params: {
            'payment': _i1.ParameterDescription(
              name: 'payment',
              type: _i1.getType<_i21.ScheduledPayment>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['scheduledPayment']
                          as _i12.ScheduledPaymentEndpoint)
                      .updatePayment(
                        session,
                        params['payment'],
                      ),
        ),
        'markAsPaid': _i1.MethodConnector(
          name: 'markAsPaid',
          params: {
            'paymentId': _i1.ParameterDescription(
              name: 'paymentId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['scheduledPayment']
                          as _i12.ScheduledPaymentEndpoint)
                      .markAsPaid(
                        session,
                        params['paymentId'],
                      ),
        ),
        'toggleActive': _i1.MethodConnector(
          name: 'toggleActive',
          params: {
            'paymentId': _i1.ParameterDescription(
              name: 'paymentId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['scheduledPayment']
                          as _i12.ScheduledPaymentEndpoint)
                      .toggleActive(
                        session,
                        params['paymentId'],
                      ),
        ),
        'deletePayment': _i1.MethodConnector(
          name: 'deletePayment',
          params: {
            'paymentId': _i1.ParameterDescription(
              name: 'paymentId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['scheduledPayment']
                          as _i12.ScheduledPaymentEndpoint)
                      .deletePayment(
                        session,
                        params['paymentId'],
                      ),
        ),
        'getPaymentSummary': _i1.MethodConnector(
          name: 'getPaymentSummary',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['scheduledPayment']
                          as _i12.ScheduledPaymentEndpoint)
                      .getPaymentSummary(
                        session,
                        params['userId'],
                      ),
        ),
      },
    );
    connectors['transaction'] = _i1.EndpointConnector(
      name: 'transaction',
      endpoint: endpoints['transaction']!,
      methodConnectors: {
        'getTransactions': _i1.MethodConnector(
          name: 'getTransactions',
          params: {
            'type': _i1.ParameterDescription(
              name: 'type',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['transaction'] as _i13.TransactionEndpoint)
                  .getTransactions(
                    session,
                    type: params['type'],
                  ),
        ),
        'addTransaction': _i1.MethodConnector(
          name: 'addTransaction',
          params: {
            'transaction': _i1.ParameterDescription(
              name: 'transaction',
              type: _i1.getType<_i17.Transaction>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['transaction'] as _i13.TransactionEndpoint)
                  .addTransaction(
                    session,
                    params['transaction'],
                  ),
        ),
      },
    );
    connectors['transactionImport'] = _i1.EndpointConnector(
      name: 'transactionImport',
      endpoint: endpoints['transactionImport']!,
      methodConnectors: {
        'extractFromImage': _i1.MethodConnector(
          name: 'extractFromImage',
          params: {
            'imageBase64': _i1.ParameterDescription(
              name: 'imageBase64',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'mimeType': _i1.ParameterDescription(
              name: 'mimeType',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['transactionImport']
                          as _i14.TransactionImportEndpoint)
                      .extractFromImage(
                        session,
                        params['imageBase64'],
                        params['mimeType'],
                        params['userId'],
                      ),
        ),
        'extractFromPdf': _i1.MethodConnector(
          name: 'extractFromPdf',
          params: {
            'pdfBase64': _i1.ParameterDescription(
              name: 'pdfBase64',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['transactionImport']
                          as _i14.TransactionImportEndpoint)
                      .extractFromPdf(
                        session,
                        params['pdfBase64'],
                        params['userId'],
                      ),
        ),
        'importTransactions': _i1.MethodConnector(
          name: 'importTransactions',
          params: {
            'transactionData': _i1.ParameterDescription(
              name: 'transactionData',
              type: _i1.getType<List<Map<String, dynamic>>>(),
              nullable: false,
            ),
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['transactionImport']
                          as _i14.TransactionImportEndpoint)
                      .importTransactions(
                        session,
                        params['transactionData'],
                        params['userId'],
                      ),
        ),
        'getImportStats': _i1.MethodConnector(
          name: 'getImportStats',
          params: {
            'userId': _i1.ParameterDescription(
              name: 'userId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['transactionImport']
                          as _i14.TransactionImportEndpoint)
                      .getImportStats(
                        session,
                        params['userId'],
                      ),
        ),
      },
    );
    connectors['userProfile'] = _i1.EndpointConnector(
      name: 'userProfile',
      endpoint: endpoints['userProfile']!,
      methodConnectors: {
        'getOrCreateProfile': _i1.MethodConnector(
          name: 'getOrCreateProfile',
          params: {
            'uid': _i1.ParameterDescription(
              name: 'uid',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['userProfile'] as _i15.UserProfileEndpoint)
                  .getOrCreateProfile(
                    session,
                    params['uid'],
                  ),
        ),
        'awardCredits': _i1.MethodConnector(
          name: 'awardCredits',
          params: {
            'userProfileId': _i1.ParameterDescription(
              name: 'userProfileId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'amount': _i1.ParameterDescription(
              name: 'amount',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'reason': _i1.ParameterDescription(
              name: 'reason',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['userProfile'] as _i15.UserProfileEndpoint)
                  .awardCredits(
                    session,
                    params['userProfileId'],
                    params['amount'],
                    params['reason'],
                  ),
        ),
        'markGoalCompleted': _i1.MethodConnector(
          name: 'markGoalCompleted',
          params: {
            'userProfileId': _i1.ParameterDescription(
              name: 'userProfileId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'goalId': _i1.ParameterDescription(
              name: 'goalId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['userProfile'] as _i15.UserProfileEndpoint)
                  .markGoalCompleted(
                    session,
                    params['userProfileId'],
                    params['goalId'],
                  ),
        ),
        'getCreditBalance': _i1.MethodConnector(
          name: 'getCreditBalance',
          params: {
            'userProfileId': _i1.ParameterDescription(
              name: 'userProfileId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['userProfile'] as _i15.UserProfileEndpoint)
                  .getCreditBalance(
                    session,
                    params['userProfileId'],
                  ),
        ),
        'checkAndAwardSavingsBonus': _i1.MethodConnector(
          name: 'checkAndAwardSavingsBonus',
          params: {
            'userProfileId': _i1.ParameterDescription(
              name: 'userProfileId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
            'savingsRate': _i1.ParameterDescription(
              name: 'savingsRate',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['userProfile'] as _i15.UserProfileEndpoint)
                  .checkAndAwardSavingsBonus(
                    session,
                    params['userProfileId'],
                    params['savingsRate'],
                  ),
        ),
      },
    );
    connectors['greeting'] = _i1.EndpointConnector(
      name: 'greeting',
      endpoint: endpoints['greeting']!,
      methodConnectors: {
        'hello': _i1.MethodConnector(
          name: 'hello',
          params: {
            'name': _i1.ParameterDescription(
              name: 'name',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['greeting'] as _i16.GreetingEndpoint).hello(
                session,
                params['name'],
              ),
        ),
      },
    );
    modules['serverpod_auth_idp'] = _i22.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_auth_core'] = _i23.Endpoints()
      ..initializeEndpoints(server);
  }
}
