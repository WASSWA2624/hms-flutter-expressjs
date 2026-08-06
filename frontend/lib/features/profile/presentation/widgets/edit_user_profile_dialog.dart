import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class EditUserProfileDialog extends StatefulWidget {
  const EditUserProfileDialog({required this.record, super.key});

  final UserProfileRecord record;

  @override
  State<EditUserProfileDialog> createState() => _EditUserProfileDialogState();
}

class _EditUserProfileDialogState extends State<EditUserProfileDialog> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  String? _gender;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.record.firstName);
    _middleNameController = TextEditingController(
      text: widget.record.middleName,
    );
    _lastNameController = TextEditingController(text: widget.record.lastName);
    _gender = widget.record.gender;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.profileEditDialogTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.profileEditDialogBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _firstNameController,
            labelText: l10n.profileEditFirstNameLabel,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _middleNameController,
            labelText: l10n.profileEditMiddleNameLabel,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _lastNameController,
            labelText: l10n.profileEditLastNameLabel,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppSelectField<String>(
            labelText: l10n.profileEditGenderLabel,
            value: _gender,
            options: <AppSelectOption<String>>[
              AppSelectOption<String>(
                value: 'MALE',
                label: l10n.profileGenderMale,
              ),
              AppSelectOption<String>(
                value: 'FEMALE',
                label: l10n.profileGenderFemale,
              ),
              AppSelectOption<String>(
                value: 'OTHER',
                label: l10n.profileGenderOther,
              ),
              AppSelectOption<String>(
                value: 'UNKNOWN',
                label: l10n.profileGenderUnknown,
              ),
            ],
            onChanged: (String? value) {
              setState(() {
                _gender = value;
              });
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.close(
          leadingIcon: AppActionIcons.cancel,
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.commonSaveActionLabel,
          onPressed: () {
            Navigator.of(context).pop(
              UserProfileDraft(
                firstName: _firstNameController.text.trim(),
                middleName: _middleNameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                gender: _gender,
              ),
            );
          },
        ),
      ],
    );
  }
}
