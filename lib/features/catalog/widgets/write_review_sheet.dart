import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../../../data/models/engagement.dart';
import '../../../data/repositories/repositories.dart';
import 'review_widgets.dart';

//==============================================================================
// SPOCART — Write a review
//------------------------------------------------------------------------------
// Opens for a product the buyer has received. The server has the final say on
// whether they may review it, so a refusal is shown exactly as the server
// worded it rather than guessed at here.
//==============================================================================

/// Returns true when a review was saved.
Future<bool> showWriteReviewSheet(
  BuildContext context, {
  required String productId,
  required String productName,
  ProductReview? existing,
}) async {
  final bool? saved = await showAppBottomSheet<bool>(
    context,
    title: existing == null ? 'Write a review' : 'Edit your review',
    builder: (context) => _WriteReviewBody(
      productId: productId,
      productName: productName,
      existing: existing,
    ),
  );
  return saved ?? false;
}

class _WriteReviewBody extends StatefulWidget {
  const _WriteReviewBody({
    required this.productId,
    required this.productName,
    this.existing,
  });

  final String productId;
  final String productName;
  final ProductReview? existing;

  @override
  State<_WriteReviewBody> createState() => _WriteReviewBodyState();
}

class _WriteReviewBodyState extends State<_WriteReviewBody> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _body =
      TextEditingController(text: widget.existing?.body ?? '');
  late int _rating = widget.existing?.rating ?? 0;

  bool _saving = false;
  String? _ratingError;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final bool formOk = _form.currentState?.validate() ?? false;
    setState(() => _ratingError = _rating == 0 ? 'Choose a star rating' : null);
    if (!formOk || _rating == 0) return;

    setState(() => _saving = true);
    try {
      await AppScope.of(context).reviews.submit(
            widget.productId,
            rating: _rating,
            title: _title.text.trim(),
            body: _body.text.trim(),
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Thanks — your review is live.',
          tone: SnackTone.success);
      Navigator.of(context).pop(true);
    } on AppException catch (e) {
      // The server's reason, verbatim: it knows whether the order was delivered.
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not save your review. Please try again.',
            tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.productName, style: AppTypography.bodyStrong),
            const SizedBox(height: AppSpacing.md),
            StarPicker(
              value: _rating,
              onChanged: (int v) => setState(() {
                _rating = v;
                _ratingError = null;
              }),
            ),
            if (_ratingError != null) ...[
              const SizedBox(height: 4),
              Text(_ratingError!,
                  style: AppTypography.caption.copyWith(color: AppColors.red)),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _title,
              label: 'Headline',
              hint: 'Optional — e.g. "Held up all season"',
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _body,
              label: 'Your review',
              required: true,
              hint: 'How did it work for your team?',
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              validator: (String? v) =>
                  (v ?? '').trim().length < 4 ? 'Tell other buyers a little about it' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: widget.existing == null ? 'Post Review' : 'Save Changes',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
