// The extension keeps the dashboard layout separate from the existing page.
// ignore_for_file: invalid_use_of_protected_member
part of 'system_settings_page.dart';

enum _SettingsSection { stock, hours, discounts, assignment, gcash }

extension _SettingsDashboard on _SystemSettingsPageState {
  static const _ink = Color(0xFF171717);
  static const _muted = Color(0xFF83776F);
  static const _line = Color(0xFFE9E2DC);
  static const _orange = Color(0xFFC94008);

  Future<void> _loadDashboardExtras() async {
    final locationId = widget.controller.activeLocationId;
    if (locationId == null) {
      if (mounted) setState(() => _isLoadingDashboardExtras = false);
      return;
    }
    try {
      final row = await widget.controller.supabase
          .from('store_settings')
          .select(
            'auto_assign_orders, max_active_orders_per_helper, '
            'max_approved_discount_pct, gcash_enabled, gcash_account_name, '
            'gcash_number, gcash_merchant_id',
          )
          .eq('location_id', locationId)
          .maybeSingle();
      final cashiers = await widget.controller.supabase
          .from('profiles')
          .select('id, cashier_discount_limit_pct')
          .eq('location_id', locationId)
          .inFilter('role', ['staff', 'cashier']);
      if (!mounted || widget.controller.activeLocationId != locationId) return;
      setState(() {
        _autoAssignOrders = row?['auto_assign_orders'] != false;
        _maxHelperOrders =
            (row?['max_active_orders_per_helper'] as num?)?.toInt() ?? 3;
        _maxApprovedDiscount =
            (row?['max_approved_discount_pct'] as num?)?.toDouble() ?? 25;
        _gcashEnabled = row?['gcash_enabled'] != false;
        _gcashAccountCtrl.text = row?['gcash_account_name']?.toString() ?? '';
        _gcashNumberCtrl.text = row?['gcash_number']?.toString() ?? '';
        _gcashMerchantCtrl.text = row?['gcash_merchant_id']?.toString() ?? '';
        final currentIds = cashiers
            .map((item) => item['id'].toString())
            .toSet();
        for (final id in _cashierLimitCtrls.keys.toList()) {
          if (!currentIds.contains(id)) {
            _cashierLimitCtrls.remove(id)?.dispose();
          }
        }
        for (final item in cashiers) {
          final id = item['id'].toString();
          _cashierLimitCtrls.putIfAbsent(id, TextEditingController.new).text =
              (item['cashier_discount_limit_pct'] as num?)?.toString() ?? '';
        }
        _isLoadingDashboardExtras = false;
        _dashboardError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingDashboardExtras = false;
        _dashboardError = 'New settings require the Settings SQL migration.';
      });
    }
  }

  Future<void> _saveDashboardExtras() async {
    final defaultLimit = double.tryParse(_discountLimitCtrl.text.trim());
    if (_maxHelperOrders < 1 ||
        _maxHelperOrders > 30 ||
        _maxApprovedDiscount < 0 ||
        _maxApprovedDiscount > 100 ||
        defaultLimit == null ||
        defaultLimit < 0 ||
        defaultLimit > _maxApprovedDiscount) {
      setState(() => _dashboardError = 'Review the order and discount limits.');
      return;
    }
    final limits = <String, double>{};
    for (final entry in _cashierLimitCtrls.entries) {
      if (entry.value.text.trim().isEmpty) continue;
      final value = double.tryParse(entry.value.text.trim());
      if (value == null || value < 0 || value > _maxApprovedDiscount) {
        setState(
          () => _dashboardError = 'Cashier limits must be valid percentages.',
        );
        return;
      }
      limits[entry.key] = value;
    }
    setState(() {
      _isSavingDashboard = true;
      _dashboardError = null;
    });
    try {
      await widget.controller.saveSettingsDashboardExtras(
        autoAssignOrders: _autoAssignOrders,
        maxHelperOrders: _maxHelperOrders,
        maxApprovedDiscount: _maxApprovedDiscount,
        defaultCashierLimit: defaultLimit,
        acceptGcash: _gcashEnabled,
        gcashAccountName: _gcashAccountCtrl.text,
        gcashNumber: _gcashNumberCtrl.text,
        gcashMerchantId: _gcashMerchantCtrl.text,
        cashierLimits: limits,
      );
      if (mounted) _showToast('Settings saved');
      _discountLimitBaseline = defaultLimit;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Dashboard settings save failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(
          () => _dashboardError = AppErrorMapper.message(
            error,
            fallback: AppErrorCategory.dataSave,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingDashboard = false);
    }
  }

  Future<void> _saveDashboardSection() async {
    switch (_selectedSettingsSection) {
      case _SettingsSection.stock:
        await _saveGlobalThresholds();
        return;
      case _SettingsSection.hours:
        await _saveStoreAccessSettings();
        return;
      case _SettingsSection.discounts:
        await _saveDashboardExtras();
        return;
      case _SettingsSection.assignment:
      case _SettingsSection.gcash:
        await _saveDashboardExtras();
        return;
    }
  }

  void _discardDashboardSection() {
    switch (_selectedSettingsSection) {
      case _SettingsSection.stock:
        final value = _thresholdBaseline;
        if (value != null) {
          _lowPercentCtrl.text = _formatPct(value.low);
          _criticalPercentCtrl.text = _formatPct(value.critical);
        }
        break;
      case _SettingsSection.hours:
        final value = _storeAccessBaseline;
        if (value != null) _applyStoreAccessToForm(value);
        break;
      case _SettingsSection.discounts:
        final value = _discountLimitBaseline;
        if (value != null) _discountLimitCtrl.text = _formatPct(value);
        _loadDashboardExtras();
        break;
      case _SettingsSection.assignment:
      case _SettingsSection.gcash:
        _loadDashboardExtras();
        break;
    }
    setState(() => _dashboardError = null);
  }

  Widget _buildSettingsDashboard(BuildContext context) {
    final busy =
        _isLoadingSettings ||
        _isLoadingStoreAccess ||
        _isLoadingDashboardExtras;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F3),
      body: busy
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(36, 40, 36, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settings',
                              style: TextStyle(
                                fontFamily: _fontFam,
                                fontSize: 27,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Store-wide rules and preferences.',
                              style: TextStyle(
                                fontFamily: _fontFam,
                                fontSize: 15,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _discardDashboardSection,
                        child: const Text('Discard'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed:
                            _isSavingDashboard ||
                                _isSavingThresholds ||
                                _isSavingStoreAccess ||
                                _isSavingDiscountLimit
                            ? null
                            : _saveDashboardSection,
                        style: FilledButton.styleFrom(backgroundColor: _orange),
                        child: const Text('Save settings'),
                      ),
                    ],
                  ),
                  if (_dashboardError != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _dashboardError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 30),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 720;
                      final nav = SizedBox(
                        width: narrow ? double.infinity : 270,
                        child: Column(
                          children: [
                            _sectionButton(
                              'Stock & units',
                              _SettingsSection.stock,
                            ),
                            _sectionButton(
                              'Store hours & access',
                              _SettingsSection.hours,
                            ),
                            _sectionButton(
                              'Discounts',
                              _SettingsSection.discounts,
                            ),
                            _sectionButton(
                              'Order assignment',
                              _SettingsSection.assignment,
                            ),
                            _sectionButton(
                              'GCash payments',
                              _SettingsSection.gcash,
                            ),
                          ],
                        ),
                      );
                      final card = _settingsCard();
                      return narrow
                          ? Column(
                              children: [nav, const SizedBox(height: 16), card],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                nav,
                                const SizedBox(width: 30),
                                Expanded(child: card),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionButton(String label, _SettingsSection section) {
    final selected = _selectedSettingsSection == section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedSettingsSection = section),
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: _fontFam,
                    fontSize: 15,
                    color: _ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsCard() {
    final title = switch (_selectedSettingsSection) {
      _SettingsSection.stock => 'Stock & units',
      _SettingsSection.hours => 'Store hours & access',
      _SettingsSection.discounts => 'Discounts',
      _SettingsSection.assignment => 'Order assignment',
      _SettingsSection.gcash => 'GCash payments',
    };
    final subtitle = switch (_selectedSettingsSection) {
      _SettingsSection.stock =>
        'Stock alerts and the units products can be sold in.',
      _SettingsSection.hours => 'When the store is open and staff may sign in.',
      _SettingsSection.discounts =>
        'How much cashiers may discount before approval.',
      _SettingsSection.assignment => 'How new orders reach helpers.',
      _SettingsSection.gcash =>
        'The merchant account customers pay at checkout.',
    };
    final body = switch (_selectedSettingsSection) {
      _SettingsSection.stock => _stockSection(),
      _SettingsSection.hours => _hoursSection(),
      _SettingsSection.discounts => _discountSection(),
      _SettingsSection.assignment => _assignmentSection(),
      _SettingsSection.gcash => _gcashSection(),
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: _fontFam,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: _fontFam,
                    fontSize: 14,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          Padding(padding: const EdgeInsets.all(26), child: body),
        ],
      ),
    );
  }

  Widget _numberField(
    String label,
    TextEditingController controller, {
    double width = 260,
    String? hint,
  }) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _stockSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          _numberField('Low stock at (% of max)', _lowPercentCtrl),
          _numberField('Critical at (% of max)', _criticalPercentCtrl),
        ],
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: 560,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: const [
              Expanded(
                flex: 1,
                child: ColoredBox(
                  color: Color(0xFFB91C1C),
                  child: SizedBox(height: 9),
                ),
              ),
              Expanded(
                flex: 2,
                child: ColoredBox(
                  color: Color(0xFFB45309),
                  child: SizedBox(height: 9),
                ),
              ),
              Expanded(
                flex: 7,
                child: ColoredBox(
                  color: Color(0xFF15803D),
                  child: SizedBox(height: 9),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 9),
      Text(
        'A product with max 200 turns critical at '
        '${(200 * (double.tryParse(_criticalPercentCtrl.text) ?? 0) / 100).round()} '
        'and low at ${(200 * (double.tryParse(_lowPercentCtrl.text) ?? 0) / 100).round()}.',
        style: const TextStyle(color: _muted, fontSize: 13),
      ),
      const SizedBox(height: 28),
      const Text(
        'Measurement units',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            for (final unit in _measurements)
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _line)),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(unit.name),
                  leading: SizedBox(
                    width: 58,
                    child: Text(
                      unit.symbol,
                      style: const TextStyle(color: _muted),
                    ),
                  ),
                  onTap: () => _showMeasurementModal(unit),
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 17),
                    tooltip: 'Delete ${unit.name}',
                    onPressed: () => _confirmDeleteMeasurement(unit),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _showMeasurementModal(),
                icon: const Icon(LucideIcons.plus, size: 17),
                label: const Text('Add unit'),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _hoursSection() {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var day = 1; day <= 7; day++)
          Builder(
            builder: (context) {
              final schedule =
                  _weeklyHoursDraft[day] ??
                  StoreDayHours(
                    openingTime: _formatClockTime(_openingTime),
                    closingTime: _formatClockTime(_closingTime),
                  );
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _line)),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 125,
                      child: Text(
                        names[day - 1],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: schedule.closed
                          ? null
                          : () async {
                              final value = await showTimePicker(
                                context: context,
                                initialTime: _parseClockTime(
                                  schedule.openingTime,
                                ),
                              );
                              if (value == null || !mounted) return;
                              setState(
                                () => _weeklyHoursDraft[day] = StoreDayHours(
                                  openingTime: _formatClockTime(value),
                                  closingTime: schedule.closingTime,
                                ),
                              );
                            },
                      child: Text(
                        _formatDisplayTime(
                          _parseClockTime(schedule.openingTime),
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: schedule.closed
                          ? null
                          : () async {
                              final value = await showTimePicker(
                                context: context,
                                initialTime: _parseClockTime(
                                  schedule.closingTime,
                                ),
                              );
                              if (value == null || !mounted) return;
                              setState(
                                () => _weeklyHoursDraft[day] = StoreDayHours(
                                  openingTime: schedule.openingTime,
                                  closingTime: _formatClockTime(value),
                                ),
                              );
                            },
                      child: Text(
                        _formatDisplayTime(
                          _parseClockTime(schedule.closingTime),
                        ),
                      ),
                    ),
                    Checkbox(
                      value: schedule.closed,
                      onChanged: (value) => setState(() {
                        _weeklyHoursDraft[day] = StoreDayHours(
                          openingTime: schedule.openingTime,
                          closingTime: schedule.closingTime,
                          closed: value ?? false,
                        );
                      }),
                    ),
                    const Text('Closed'),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Limit staff sign-in to store hours'),
          subtitle: const Text(
            'Cashiers and helpers are blocked outside the schedule.',
          ),
          value: _restrictStaffLogin,
          onChanged: (value) => setState(() => _restrictStaffLogin = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Administrators are exempt'),
          value: _allowAdminAnytime,
          onChanged: (value) => setState(() => _allowAdminAnytime = value),
        ),
        const SizedBox(height: 12),
        _numberField(
          'Grace period before opening (min)',
          _beforeMinutesCtrl,
          width: 280,
        ),
        const SizedBox(height: 12),
        _numberField(
          'Grace period after closing (min)',
          _afterMinutesCtrl,
          width: 280,
        ),
        if (_storeAccessError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _storeAccessError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _discountSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          _numberField('Default cashier limit (%)', _discountLimitCtrl),
          SizedBox(
            width: 260,
            child: TextFormField(
              key: ValueKey('maximum-$_maxApprovedDiscount'),
              initialValue: _formatPct(_maxApprovedDiscount),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximum with approval (%)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _maxApprovedDiscount =
                  double.tryParse(value) ?? _maxApprovedDiscount,
            ),
          ),
        ],
      ),
      const SizedBox(height: 27),
      const Text(
        'Per-cashier limits',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 5),
      const Text(
        'Leave blank to use the default.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 12),
      for (final staff in _staffList.where(
        (row) => [
          'staff',
          'cashier',
        ].contains(row['role']?.toString().toLowerCase()),
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              Expanded(child: Text(staff['name']?.toString() ?? 'Cashier')),
              _numberField(
                'Limit %',
                _cashierLimitCtrls.putIfAbsent(
                  staff['id'].toString(),
                  TextEditingController.new,
                ),
                width: 125,
              ),
            ],
          ),
        ),
      if (_discountLimitError != null)
        Text(_discountLimitError!, style: const TextStyle(color: Colors.red)),
    ],
  );

  Widget _assignmentSection() => Column(
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Assign new orders automatically'),
        subtitle: const Text(
          'Selects the available helper with the fewest active orders.',
        ),
        value: _autoAssignOrders,
        onChanged: (value) => setState(() => _autoAssignOrders = value),
      ),
      const Divider(color: _line),
      Row(
        children: [
          const Expanded(child: Text('Most active orders per helper')),
          SizedBox(
            width: 95,
            child: TextFormField(
              key: ValueKey('helper-limit-$_maxHelperOrders'),
              initialValue: '$_maxHelperOrders',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (value) =>
                  _maxHelperOrders = int.tryParse(value) ?? _maxHelperOrders,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _gcashSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Accept GCash at the register'),
        value: _gcashEnabled,
        onChanged: (value) => setState(() => _gcashEnabled = value),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _gcashAccountCtrl,
        decoration: const InputDecoration(
          labelText: 'Account name',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _gcashNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'GCash number',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _gcashMerchantCtrl,
              decoration: const InputDecoration(
                labelText: 'Merchant ID',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const Text('QR shown at checkout', style: TextStyle(color: _muted)),
      const SizedBox(height: 8),
      if (widget.controller.gcashQrUrl.isNotEmpty)
        Image.network(
          widget.controller.gcashQrUrl,
          width: 180,
          height: 180,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('QR image unavailable'),
        ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _isUploadingQr ? null : _uploadGcashQr,
        icon: const Icon(LucideIcons.upload, size: 17),
        label: Text(_isUploadingQr ? 'Uploading…' : 'Upload QR image'),
      ),
      const SizedBox(height: 15),
      const Text(
        'Cashiers record the reference from the customer’s GCash receipt.',
        style: TextStyle(color: _muted, fontSize: 13),
      ),
    ],
  );
}
