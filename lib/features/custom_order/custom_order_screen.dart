import 'package:file_picker/file_picker.dart';
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
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../data/models/catalog.dart';
import '../../data/models/engagement.dart';
import '../../data/repositories/repositories.dart';
import '../catalog/widgets/product_widgets.dart';

//==============================================================================
// SPOCART — Custom / Team Order
//------------------------------------------------------------------------------
// Banner → three steps (Upload Design, Choose Product, Get Quote) → the
// request form. Submitting files a QuoteRequest of kind `custom`.
//==============================================================================

class CustomOrderScreen extends StatefulWidget {
  const CustomOrderScreen({super.key});

  @override
  State<CustomOrderScreen> createState() => _CustomOrderScreenState();
}

class _CustomOrderScreenState extends State<CustomOrderScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey _formAnchor = GlobalKey();
  final TextEditingController _team = TextEditingController();
  final TextEditingController _qty = TextEditingController(text: '15');
  final TextEditingController _notes = TextEditingController();
  final Set<String> _sizes = <String>{};
  Product? _product;
  PlatformFile? _design;
  bool _submitting = false;
  QuoteRequest? _submitted;

  @override
  void dispose() {
    _team.dispose();
    _qty.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _scrollToForm() {
    final BuildContext? ctx = _formAnchor.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: AppDurations.slow,
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  Future<void> _pickDesign() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'pdf', 'ai', 'svg'],
      );
      if (file == null) return;
      final int size = await file.length();
      if (size > 25 * 1024 * 1024) {
        if (mounted) {
          showAppSnackBar(context, 'Design file must be under 25 MB.',
              tone: SnackTone.error);
        }
        return;
      }
      setState(() => _design = file);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not open the file picker.',
            tone: SnackTone.error);
      }
    }
  }

  Future<void> _chooseProduct() async {
    final AppServices services = AppScope.of(context);
    await services.catalog.load();
    if (!mounted) return;
    final List<Product> options =
        services.catalog.products.where((p) => p.customisable).toList();
    final Product? picked = await showAppBottomSheet<Product>(
      context,
      title: 'Choose Product',
      builder: (context) => ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, i) => AppCard(
          onTap: () => Navigator.of(context).pop(options[i]),
          padding: const EdgeInsets.all(10),
          borderColor:
              _product?.id == options[i].id ? AppColors.red : AppColors.border,
          child: Row(
            children: [
              ProductImage(
                source: options[i].primaryImage,
                size: 52,
                fallbackIcon: productFallbackIcon(context, options[i]),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(options[i].name, style: AppTypography.title),
                    Text('MOQ ${options[i].moq} ${options[i].unit}',
                        style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _product = picked;
        _sizes.clear();
        if (int.tryParse(_qty.text) == null ||
            int.parse(_qty.text) < picked.moq) {
          _qty.text = '${picked.moq}';
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_product == null) {
      showAppSnackBar(context, 'Choose a product for your kit first.',
          tone: SnackTone.error);
      _scrollToForm();
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final Product p = _product!;
      final String sizes = _sizes.isEmpty ? '' : ' · Sizes: ${_sizes.join(', ')}';
      final String team = _team.text.trim();
      final QuoteRequest quote = await AppScope.of(context).quotes.submit(
        kind: QuoteKind.custom,
        items: [
          QuoteItem(
            description: '${p.name} — custom for $team',
            quantity: int.parse(_qty.text.trim()),
            productId: p.id,
          ),
        ],
        notes: '${_notes.text.trim()}$sizes'.trim(),
        designFilePath: _design?.path,
        designFileName: _design?.name,
      );
      if (!mounted) return;
      setState(() => _submitted = quote);
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not submit. Please try again.',
            tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SpocartAppBar(title: 'Custom / Team Order'),
      body: _submitted != null
          ? _SuccessView(quote: _submitted!)
          : KeyboardDismisser(
              child: ContentWidth(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page, AppSpacing.xs, AppSpacing.page, 96),
                    children: [
                      _Banner(onDesign: _scrollToForm),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          _StepTile(
                            icon: Icons.upload_outlined,
                            label: 'Upload Design',
                            done: _design != null,
                            onTap: _pickDesign,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _StepTile(
                            icon: Icons.checkroom_outlined,
                            label: 'Choose Product',
                            done: _product != null,
                            onTap: _chooseProduct,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _StepTile(
                            icon: Icons.request_quote_outlined,
                            label: 'Get Quote',
                            done: false,
                            onTap: _submit,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Your kit', key: _formAnchor, style: AppTypography.h3),
                      const SizedBox(height: AppSpacing.sm),
                      _ProductPicker(product: _product, onTap: _chooseProduct),
                      if (_product != null && _product!.sizes.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        const FieldLabel(label: 'Sizes needed'),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final String s in _product!.sizes)
                              FilterChip(
                                label: Text(s),
                                selected: _sizes.contains(s),
                                onSelected: (v) => setState(() =>
                                    v ? _sizes.add(s) : _sizes.remove(s)),
                                selectedColor: AppColors.black,
                                checkmarkColor: AppColors.white,
                                labelStyle: AppTypography.smallStrong.copyWith(
                                  color: _sizes.contains(s)
                                      ? AppColors.white
                                      : AppColors.text,
                                ),
                                side: BorderSide(
                                  color: _sizes.contains(s)
                                      ? AppColors.black
                                      : AppColors.border,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _team,
                        label: 'Team / School / Club Name',
                        required: true,
                        hint: 'Printed on the kit',
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            Validators.minLength(v, 2, field: 'Team name'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _qty,
                        label: 'Quantity (${_product?.unit ?? 'pc'})',
                        required: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) =>
                            Validators.quantity(v, min: _product?.moq ?? 1),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _DesignRow(file: _design, onPick: _pickDesign,
                          onClear: () => setState(() => _design = null)),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _notes,
                        label: 'Design notes',
                        hint:
                            'Colours, sponsor logos, player names & numbers, delivery date…',
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _submitted != null
          ? null
          : BottomActionBar(
              child: PrimaryButton(
                label: 'Start Custom Order',
                loading: _submitting,
                onPressed: _submit,
              ),
            ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.onDesign});

  final VoidCallback onDesign;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.lgAll,
      child: AspectRatio(
        aspectRatio: 1.9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/football_match.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.black),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [Color(0xF20B0B0C), Color(0x800B0B0C), Color(0x330B0B0C)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Custom Jerseys & Team Kits',
                    style: AppTypography.h2.copyWith(color: AppColors.white),
                  ),
                  Text(
                    'for Schools, Clubs & Academies',
                    style: AppTypography.small
                        .copyWith(color: AppColors.textOnDarkSoft),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    label: 'Design Your Team',
                    size: ButtonSize.small,
                    expand: false,
                    onPressed: onDesign,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.icon,
    required this.label,
    required this.done,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        borderColor: done ? AppColors.success : AppColors.border,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.red, size: 22),
                ),
                if (done)
                  const Positioned(
                    right: -2,
                    top: -2,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: AppColors.success,
                      child: Icon(Icons.check_rounded,
                          size: 11, color: AppColors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppTypography.caption.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.product, required this.onTap});

  final Product? product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Product? p = product;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      borderColor: p == null ? AppColors.red : AppColors.border,
      child: Row(
        children: [
          if (p == null)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: AppRadius.mdAll,
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.red),
            )
          else
            ProductImage(
              source: p.primaryImage,
              size: 52,
              fallbackIcon: productFallbackIcon(context, p),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p?.name ?? 'Choose a product', style: AppTypography.title),
                Text(
                  p == null
                      ? 'Jerseys, kits, caps and more'
                      : '${p.brand} · MOQ ${p.moq} ${p.unit}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _DesignRow extends StatelessWidget {
  const _DesignRow({
    required this.file,
    required this.onPick,
    required this.onClear,
  });

  final PlatformFile? file;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel(label: 'Design / artwork'),
        const SizedBox(height: 6),
        AppCard(
          onTap: onPick,
          padding: const EdgeInsets.all(AppSpacing.sm),
          color: file == null ? AppColors.surface : AppColors.white,
          child: Row(
            children: [
              Icon(
                file == null
                    ? Icons.cloud_upload_outlined
                    : Icons.insert_drive_file_outlined,
                color: AppColors.red,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  file?.name ?? 'Upload PNG, JPG, PDF, AI or SVG (optional)',
                  style: AppTypography.small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (file != null)
                AppIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Remove',
                  size: 30,
                  iconSize: 18,
                  color: AppColors.textMuted,
                  onPressed: onClear,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.quote});

  final QuoteRequest quote;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.successTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 48, color: AppColors.success),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Request Submitted', style: AppTypography.h1),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Quotation ${quote.id} is with our kit team. We’ll share pricing, a mock-up and a delivery timeline within one business day.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMuted,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'View Quotations',
                onPressed: () => AppNavigator.toQuotes(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: 'Done',
                color: AppColors.black,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
