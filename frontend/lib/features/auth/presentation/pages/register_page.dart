import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/auth_failure_text.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _facilityNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _adminNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _facilityNameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _locationFocusNode = FocusNode();
  String _facilityType = 'HOSPITAL';
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _adminNameController.dispose();
    _facilityNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _adminNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _facilityNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Align(child: AppLogo(size: 48)),
                    SizedBox(height: theme.spacing.lg),
                    Text(
                      l10n.authRegisterTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      l10n.authRegisterBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    SizedBox(height: theme.spacing.lg),
                    if (state.failure != null) ...<Widget>[
                      AuthFailureText(failure: state.failure!),
                      SizedBox(height: theme.spacing.md),
                    ],
                    AppTextField(
                      controller: _adminNameController,
                      labelText: l10n.authAdminNameLabel,
                      textInputAction: TextInputAction.next,
                      validator: AppValidators.requiredText(
                        l10n.validationRequired,
                      ),
                      onChanged: (_) => _clearFormFeedback(),
                      onFocusChanged: _handleFieldFocusChanged,
                      focusNode: _adminNameFocusNode,
                      enabled: !state.isSubmitting,
                    ),
                    SizedBox(height: theme.spacing.md),
                    AppTextField(
                      controller: _emailController,
                      labelText: l10n.authEmailLabel,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.email],
                      validator: AppValidators.compose<String>([
                        AppValidators.requiredText(l10n.validationRequired),
                        AppValidators.email(
                          l10n.authEmailInvalidMessage,
                          allowEmpty: false,
                        ),
                      ]),
                      onChanged: (_) => _clearFormFeedback(),
                      onFocusChanged: _handleFieldFocusChanged,
                      focusNode: _emailFocusNode,
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
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.newPassword],
                      validator: AppValidators.minLength(
                        8,
                        l10n.authPasswordMinLengthMessage,
                        allowEmpty: false,
                      ),
                      onChanged: (_) => _clearFormFeedback(),
                      onFocusChanged: _handleFieldFocusChanged,
                      focusNode: _passwordFocusNode,
                      enabled: !state.isSubmitting,
                    ),
                    SizedBox(height: theme.spacing.md),
                    AppTextField(
                      controller: _facilityNameController,
                      labelText: l10n.authFacilityNameLabel,
                      textInputAction: TextInputAction.next,
                      validator: AppValidators.requiredText(
                        l10n.validationRequired,
                      ),
                      onChanged: (_) => _clearFormFeedback(),
                      onFocusChanged: _handleFieldFocusChanged,
                      focusNode: _facilityNameFocusNode,
                      enabled: !state.isSubmitting,
                    ),
                    SizedBox(height: theme.spacing.md),
                    AppSelectField<String>(
                      value: _facilityType,
                      labelText: l10n.authFacilityTypeLabel,
                      enabled: !state.isSubmitting,
                      options: <AppSelectOption<String>>[
                        AppSelectOption<String>(
                          value: 'HOSPITAL',
                          label: l10n.authFacilityTypeHospital,
                          leadingIcon: const Icon(
                            Icons.local_hospital_outlined,
                          ),
                        ),
                        AppSelectOption<String>(
                          value: 'CLINIC',
                          label: l10n.authFacilityTypeClinic,
                          leadingIcon: const Icon(Icons.medical_services),
                        ),
                        AppSelectOption<String>(
                          value: 'LAB',
                          label: l10n.authFacilityTypeLab,
                          leadingIcon: const Icon(Icons.biotech_outlined),
                        ),
                        AppSelectOption<String>(
                          value: 'PHARMACY',
                          label: l10n.authFacilityTypePharmacy,
                          leadingIcon: const Icon(
                            Icons.medication_liquid_outlined,
                          ),
                        ),
                        AppSelectOption<String>(
                          value: 'OTHER',
                          label: l10n.authFacilityTypeOther,
                          leadingIcon: const Icon(Icons.business_outlined),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _clearFormFeedback();
                          _resetValidationFeedback();
                          setState(() => _facilityType = value);
                        }
                      },
                    ),
                    SizedBox(height: theme.spacing.md),
                    AppTextField(
                      controller: _phoneController,
                      labelText: l10n.authPhoneOptionalLabel,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => _clearFormFeedback(),
                      onFocusChanged: _handleFieldFocusChanged,
                      focusNode: _phoneFocusNode,
                      enabled: !state.isSubmitting,
                    ),
                    SizedBox(height: theme.spacing.md),
                    AppTextField(
                      controller: _locationController,
                      labelText: l10n.authLocationOptionalLabel,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _clearFormFeedback(),
                      onFocusChanged: _handleFieldFocusChanged,
                      focusNode: _locationFocusNode,
                      enabled: !state.isSubmitting,
                    ),
                    SizedBox(height: theme.spacing.lg),
                    AppButton.primary(
                      label: l10n.authRegisterActionLabel,
                      leadingIcon: Icons.person_add_alt_1_outlined,
                      isLoading: state.isSubmitting,
                      fullWidth: true,
                      onPressed: _submit,
                    ),
                    SizedBox(height: theme.spacing.sm),
                    AppButton.tertiary(
                      label: l10n.authBackToLoginActionLabel,
                      onPressed: state.isSubmitting
                          ? null
                          : () => context.go(AppRoutes.login.location()),
                    ),
                  ],
                ),
              ),
            ),
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
    final email = _emailController.text.trim().toLowerCase();
    final registered = await ref
        .read(authControllerProvider.notifier)
        .register(
          email: email,
          password: _passwordController.text,
          adminName: _adminNameController.text,
          facilityName: _facilityNameController.text,
          facilityType: _facilityType,
          phone: _phoneController.text,
          location: _locationController.text,
        );

    if (!mounted || !registered) {
      return;
    }

    context.go(
      AppRoutes.verifyEmail.location(
        queryParameters: <String, String>{'email': email},
      ),
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
