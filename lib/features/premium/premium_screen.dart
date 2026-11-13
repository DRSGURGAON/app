import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../app/theme/brand.dart';
import '../../core/billing/billing_service.dart';
import '../../core/entitlement/entitlement.dart';
import '../../data/repositories/reminder_repository.dart';

/// DocSafe Premium: what it includes, the plans Google Play offers this user
/// (prices formatted by Play for their country), buy / restore / manage.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key, this.feature});

  /// Name of the locked feature the user tried to open, if any.
  final String? feature;

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  BillingAvailability? _availability;
  List<PlanOffer> _plans = const [];
  String? _selected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _availability = null);
    final billing = ref.read(billingServiceProvider);
    final availability = await billing.availability();
    final plans = availability == BillingAvailability.ready
        ? await billing.plans()
        : const <PlanOffer>[];
    if (!mounted) return;
    setState(() {
      _availability = availability;
      _plans = plans;
      // Yearly is the better deal: preselect it when offered.
      _selected =
          (plans.where(_isYearly).firstOrNull ?? plans.firstOrNull)?.basePlanId;
    });
    await ref.read(premiumProvider.notifier).refresh();
  }

  Future<void> _buy(PlanOffer plan) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref.read(billingServiceProvider).purchase(plan);
      await ref.read(premiumProvider.notifier).refresh();
      final message = switch (result) {
        PurchaseResultCode.purchased ||
        PurchaseResultCode.alreadyOwned => l.premiumWelcome,
        PurchaseResultCode.pending => l.premiumPendingBody,
        PurchaseResultCode.cancelled => null,
        PurchaseResultCode.unavailable => l.premiumUnavailable,
        PurchaseResultCode.failed => l.premiumPurchaseFailed,
      };
      if (message != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(premiumProvider.notifier).refresh();
      final status = ref.read(premiumProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              status.active
                  ? l.premiumRestored
                  : status.pending
                  ? l.premiumPendingBody
                  : l.premiumNothingToRestore,
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = ref.watch(premiumProvider);
    final feature = widget.feature;
    return Scaffold(
      appBar: AppBar(),
      // A short page: build it all at once (no lazy list).
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Crest(),
            const SizedBox(height: 14),
            Text(
              l.premiumTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (feature != null && !status.active)
              _Notice(
                icon: Icons.lock_outline,
                color: scheme.tertiaryContainer,
                onColor: scheme.onTertiaryContainer,
                title: l.premiumLocked(feature),
              ),
            if (status.active)
              _Notice(
                key: const Key('premium-active'),
                icon: Icons.verified_outlined,
                color: scheme.secondaryContainer,
                onColor: scheme.onSecondaryContainer,
                title: l.premiumActiveTitle,
                body: status.autoRenewing
                    ? l.premiumActiveBody
                    : l.premiumEndsNote,
              )
            else if (status.pending)
              _Notice(
                key: const Key('premium-pending'),
                icon: Icons.hourglass_top_rounded,
                color: scheme.tertiaryContainer,
                onColor: scheme.onTertiaryContainer,
                title: l.premiumPendingTitle,
                body: l.premiumPendingBody,
              ),
            const SizedBox(height: 8),
            Text(l.premiumIncludes, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            _Benefit(
              icon: Icons.draw_outlined,
              title: l.toolAnnotate,
              body: l.toolAnnotateDesc,
            ),
            _Benefit(
              icon: Icons.picture_as_pdf_outlined,
              title: l.premiumPdfTools,
              body: l.premiumPdfToolsDesc,
            ),
            _Benefit(
              icon: Icons.manage_search_rounded,
              title: l.premiumOcrSearch,
              body: l.premiumOcrSearchDesc,
            ),
            _Benefit(
              icon: Icons.notifications_active_outlined,
              title: l.premiumReminders,
              body: l.premiumRemindersDesc(freeActiveReminderLimit),
            ),
            const SizedBox(height: 12),
            if (status.active)
              OutlinedButton(
                key: const Key('premium-manage'),
                onPressed: () =>
                    ref.read(billingServiceProvider).openManageSubscriptions(),
                child: Text(l.premiumManage),
              )
            else
              ..._purchaseSection(context, l),
            const SizedBox(height: 8),
            if (_availability == BillingAvailability.ready)
              Center(
                child: TextButton(
                  key: const Key('premium-restore'),
                  onPressed: _busy ? null : _restore,
                  child: Text(l.premiumRestore),
                ),
              ),
            const SizedBox(height: 8),
            Text(l.premiumPrivacy, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  List<Widget> _purchaseSection(BuildContext context, AppLocalizations l) {
    final theme = Theme.of(context);
    final availability = _availability;
    if (availability == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (availability != BillingAvailability.ready || _plans.isEmpty) {
      final message = switch (availability) {
        BillingAvailability.notConfigured => l.premiumNotConfigured,
        BillingAvailability.unavailable => l.premiumUnavailable,
        BillingAvailability.ready => l.premiumNoPlans,
      };
      return [
        _Notice(
          key: const Key('premium-unavailable'),
          icon: Icons.info_outline,
          color: Brand.glass,
          onColor: theme.colorScheme.onSurfaceVariant,
          title: message,
        ),
        if (availability != BillingAvailability.notConfigured)
          Center(
            child: TextButton(onPressed: _load, child: Text(l.premiumTryAgain)),
          ),
      ];
    }
    final monthly = _plans.where(_isMonthly).firstOrNull;
    final selected =
        _plans.where((p) => p.basePlanId == _selected).firstOrNull ??
        _plans.first;
    return [
      Text(l.premiumChoosePlan, style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final plan in _plans)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PlanCard(
            plan: plan,
            selected: plan.basePlanId == selected.basePlanId,
            savePercent: _isYearly(plan) && monthly != null
                ? savePercent(monthly, plan)
                : null,
            onTap: () => setState(() => _selected = plan.basePlanId),
          ),
        ),
      const SizedBox(height: 8),
      FilledButton(
        key: const Key('premium-buy'),
        onPressed: _busy ? null : () => _buy(selected),
        child: _busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(
                trialDays(selected.freeTrialPeriod) != null
                    ? l.premiumStartTrial
                    : l.premiumContinue,
              ),
      ),
      const SizedBox(height: 10),
      Text(l.premiumLegal, style: theme.textTheme.bodySmall),
    ];
  }
}

bool _isMonthly(PlanOffer p) => p.billingPeriod == 'P1M';
bool _isYearly(PlanOffer p) => p.billingPeriod == 'P1Y';

/// Yearly saving against twelve monthly payments, rounded down; null if none.
@visibleForTesting
int? savePercent(PlanOffer monthly, PlanOffer yearly) {
  if (monthly.currencyCode != yearly.currencyCode) return null;
  final twelve = monthly.priceMicros * 12;
  if (twelve <= 0 || yearly.priceMicros >= twelve) return null;
  final percent = (twelve - yearly.priceMicros) * 100 ~/ twelve;
  return percent > 0 ? percent : null;
}

/// Days in an ISO 8601 trial period such as P7D, P1W or P1M (30 days).
@visibleForTesting
int? trialDays(String? period) {
  if (period == null) return null;
  final m = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$')
      .firstMatch(period);
  if (m == null) return null;
  int part(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
  final days = part(1) * 365 + part(2) * 30 + part(3) * 7 + part(4);
  return days > 0 ? days : null;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
    this.savePercent,
  });

  final PlanOffer plan;
  final bool selected;
  final int? savePercent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final yearly = _isYearly(plan);
    final monthly = _isMonthly(plan);
    final name = yearly
        ? l.premiumYearlyLabel
        : monthly
        ? l.premiumMonthlyLabel
        : plan.basePlanId;
    final price = yearly
        ? l.premiumPerYear(plan.formattedPrice)
        : monthly
        ? l.premiumPerMonth(plan.formattedPrice)
        : plan.formattedPrice;
    final trial = trialDays(plan.freeTrialPeriod);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Card(
        key: Key('plan-${plan.basePlanId}'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: selected ? Brand.gold : Brand.glassBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? Brand.gold : theme.colorScheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(price, style: theme.textTheme.bodyLarge),
                      if (trial != null)
                        Text(
                          l.premiumFreeTrial(trial),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFFFD27A),
                          ),
                        ),
                    ],
                  ),
                ),
                if (savePercent != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: const ShapeDecoration(
                      shape: StadiumBorder(),
                      gradient: Brand.premiumGradient,
                    ),
                    child: Text(
                      l.premiumSave(savePercent!),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF3D2600),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Crest extends StatelessWidget {
  const _Crest();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: Brand.premiumGradient,
          boxShadow: [
            BoxShadow(color: Brand.gold.withValues(alpha: .35), blurRadius: 32),
          ],
        ),
        child: const Icon(
          Icons.workspace_premium,
          size: 46,
          color: Color(0xFF3D2600),
        ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.color,
    required this.onColor,
    required this.title,
    this.body,
  });

  final IconData icon;
  final Color color;
  final Color onColor;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      color: color,
      child: ListTile(
        leading: Icon(icon, color: onColor),
        title: Text(title, style: TextStyle(color: onColor)),
        subtitle: body == null
            ? null
            : Text(body!, style: TextStyle(color: onColor)),
      ),
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: Brand.gold),
    title: Text(title),
    subtitle: Text(body),
  );
}
