import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_page_frame.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_text_link.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({required this.from, super.key});

  final String? from;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return AuthPageFrame(
      title: l10n.authLoginTitle,
      subtitle: l10n.authLoginBody,
      useCard: true,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (state.failure != null) ...<Widget>[
                AppFormInformationBanner.failure(
                  context: context,
                  failure: state.failure!,
                ),
                SizedBox(height: theme.spacing.md),
              ],
              AppTextField(
                controller: _identifierController,
                labelText: l10n.authIdentifierLabel,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[
                  AutofillHints.username,
                  AutofillHints.email,
                  AutofillHints.telephoneNumber,
                ],
                validator: AppValidators.requiredText(l10n.validationRequired),
                isRequired: true,
                onChanged: (_) => _clearFormFeedback(),
                onFocusChanged: _handleFieldFocusChanged,
                focusNode: _identifierFocusNode,
                enabled: !state.isSubmitting,
              ),
              SizedBox(height: theme.spacing.md),
              AppTextField(
                controller: _passwordController,
                labelText: l10n.authPasswordLabel,
                obscureText: true,
                enableObscureTextToggle: true,
                showObscuredTextLabel: l10n.authShowPasswordLabel,
                hideObscuredTextLabel: l10n.authHidePasswordLabel,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                validator: AppValidators.requiredText(
                  l10n.validationRequired,
                  trim: false,
                ),
                isRequired: true,
                onChanged: (_) => _clearFormFeedback(),
                onFocusChanged: _handleFieldFocusChanged,
                focusNode: _passwordFocusNode,
                enabled: !state.isSubmitting,
                onFieldSubmitted: (_) => _submit(),
              ),
              SizedBox(height: theme.spacing.lg),
              AppButton.primary(
                label: l10n.authLoginActionLabel,
                leadingIcon: Icons.login,
                isLoading: state.isSubmitting,
                fullWidth: true,
                onPressed: _submit,
              ),
              AuthTextLink(
                label: l10n.authForgotPasswordActionLabel,
                onPressed: state.isSubmitting
                    ? null
                    : () => context.go(AppRoutes.forgotPassword.location()),
              ),
              AuthTextLink(
                label: l10n.authCreateAccountActionLabel,
                onPressed: state.isSubmitting
                    ? null
                    : () => context.go(AppRoutes.register.location()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    ref.read(authControllerProvider.notifier).clearFailure();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      _enableValidationRefresh();
      return;
    }

    TextInput.finishAutofillContext();
    final success = await ref
        .read(authControllerProvider.notifier)
        .login(
          identifier: _identifierController.text,
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (!success) {
      final failure = ref.read(authControllerProvider).failure;
      if (failure?.code == 'auth.account_pending') {
        final identifier = _identifierController.text.trim();
        context.go(
          AppRoutes.verifyEmail.location(
            queryParameters: <String, String>{
              if (identifier.contains('@')) 'email': identifier.toLowerCase(),
              'reason': 'pending',
            },
          ),
        );
      } else if (failure?.code == 'auth.account_pending_approval') {
        // Stay on login — failure message explains approval is pending.
      }
      return;
    }

    final from = widget.from;
    context.go(
      from == null || from.isEmpty || from == AppRoutes.login.path
          ? AppRoutes.home.location()
          : from,
    );
  }

  void _handleFieldFocusChanged(bool hasFocus) {
    if (hasFocus) {
      _clearFormFeedback();
    }
    _resetValidationFeedback();
  }

  void _clearFormFeedback() {
    ref.read(authControllerProvider.notifier).clearFailure();
  }

  void _enableValidationRefresh() {
    if (_autovalidateMode == AutovalidateMode.onUserInteraction) {
      return;
    }

    setState(() {
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });
  }

  void _resetValidationFeedback() {
    if (_autovalidateMode == AutovalidateMode.disabled) {
      return;
    }

    setState(() {
      _formKey = GlobalKey<FormState>();
      _autovalidateMode = AutovalidateMode.disabled;
    });
  }
}
