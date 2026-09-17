import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../data/models/catalog.dart';
import '../../data/models/engagement.dart';
import '../../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Request for Quote sheet
//------------------------------------------------------------------------------
// Opened from Bulk Pricing. Captures quantity + requirements for one product
// and files a QuoteRequest. Resolves with the created quote (or null).
//==============================================================================

Future<QuoteRequest?> showRequestQuoteSheet(
  BuildContext context, {
  required Product product,
}) {
  return showAppBottomSheet<QuoteRequest>(
    context,
    title: 'Request for Quote',
    builder: (context) => _RequestQuoteForm(product: product),
  );
}

class _RequestQuoteForm extends StatefulWidget {
  const _RequestQuoteForm({required this.product});

  final Product product;

  @override
  State<_RequestQuoteForm> createState() => _RequestQuoteFormState();
}

class _RequestQuoteFormState extends State<_RequestQuoteForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _qty =
      TextEditingController(text: '${widget.product.tiers.last.minQty}');
  final TextEditingController _notes = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _qty.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final QuoteRequest quote = await AppScope.of(context).quotes.submit(
        kind: QuoteKind.bulk,
        items: [
          QuoteItem(
            description: widget.product.name,
            quantity: int.parse(_qty.text.trim()),
            productId: widget.product.id,
          ),
        ],
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(quote);
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not submit the request. Try again.',
            tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Product p = widget.product;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.name, style: AppTypography.title),
            Text('${p.brand} · MOQ ${p.moq} ${p.unit}',
                style: AppTypography.small),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _qty,
              label: 'Quantity (${p.unit})',
              required: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => Validators.quantity(v, min: p.moq),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _notes,
              label: 'Requirements',
              hint: 'Sizes, branding, delivery timeline, budget…',
              maxLines: 3,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Submit Request',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard follow-up after a quote is filed: success snackbar with a link to
/// the quotations list.
void confirmQuoteSubmitted(BuildContext context, QuoteRequest quote) {
  showAppSnackBar(
    context,
    'Request ${quote.id} submitted. We’ll respond within one business day.',
    tone: SnackTone.success,
    actionLabel: 'View',
    onAction: () => AppNavigator.toQuotes(context),
    duration: const Duration(seconds: 5),
  );
}
