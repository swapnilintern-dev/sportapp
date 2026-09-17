import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/feedback.dart';

//==============================================================================
// SPOCART — "Need Help with This Order?" sheet
//------------------------------------------------------------------------------
// Three real contact channels: WhatsApp chat with pre-filled context, a phone
// call, and a plain WhatsApp conversation. Each launches the platform handler
// via url_launcher and reports honestly when the device cannot open it.
//==============================================================================

Future<void> showHelpSheet(
  BuildContext context, {
  String title = 'Need Help with This Order?',
  String? about,
}) {
  return showAppBottomSheet<void>(
    context,
    title: title,
    builder: (sheetContext) => _HelpSheetBody(
      contextMessage: about,
    ),
  );
}

class _HelpSheetBody extends StatelessWidget {
  const _HelpSheetBody({this.contextMessage});

  final String? contextMessage;

  @override
  Widget build(BuildContext context) {
    final String message = contextMessage == null
        ? 'Hi SPOCART, I need help with my order.'
        : 'Hi SPOCART, I need help with: $contextMessage';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetOptionTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Chat Now',
            subtitle: 'Get instant support',
            iconColor: AppColors.red,
            iconBackground: AppColors.redTint,
            onTap: () => SupportLauncher.whatsapp(context, message: message),
          ),
          SheetOptionTile(
            icon: Icons.call_outlined,
            title: 'Call Us',
            subtitle: SupportContacts.phoneDisplay,
            iconColor: AppColors.black,
            iconBackground: AppColors.surfaceAlt,
            onTap: () => SupportLauncher.call(context),
          ),
          SheetOptionTile(
            icon: Icons.forum_outlined,
            title: 'WhatsApp',
            subtitle: 'Quick assistance',
            iconColor: AppColors.success,
            iconBackground: AppColors.successTint,
            onTap: () => SupportLauncher.whatsapp(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            SupportContacts.hours,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

/// Opens the phone / WhatsApp / email handlers. Every method surfaces a
/// snackbar when the device has no app that can handle the link.
abstract final class SupportLauncher {
  static Future<void> call(BuildContext context) => _open(
        context,
        Uri(scheme: 'tel', path: SupportContacts.phoneDial),
        failure: 'Calling is not available on this device. '
            'Reach us on ${SupportContacts.phoneDisplay}.',
      );

  static Future<void> whatsapp(BuildContext context, {String? message}) =>
      _open(
        context,
        Uri.https('wa.me', '/${SupportContacts.whatsappNumber}',
            message == null ? null : <String, String>{'text': message}),
        failure: 'WhatsApp is not installed. '
            'Message us on ${SupportContacts.phoneDisplay}.',
      );

  static Future<void> email(BuildContext context, {String? subject}) => _open(
        context,
        Uri(
          scheme: 'mailto',
          path: SupportContacts.email,
          queryParameters: subject == null ? null : {'subject': subject},
        ),
        failure: 'No email app found. Write to ${SupportContacts.email}.',
      );

  static Future<void> website(BuildContext context, [String url = AppInfo.website]) =>
      _open(
        context,
        Uri.parse(url),
        failure: 'Could not open the browser.',
      );

  static Future<void> _open(BuildContext context, Uri uri,
      {required String failure}) async {
    bool ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      showAppSnackBar(context, failure, tone: SnackTone.error);
    }
  }
}
