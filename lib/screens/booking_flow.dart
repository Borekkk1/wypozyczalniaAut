import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cars_page.dart' show C, CarGroup;

// ═══════════════════════════════════════════════════════════════════════
// BOOKING FLOW — wbudowany w modal auta
// ═══════════════════════════════════════════════════════════════════════
class BookingFlow extends StatefulWidget {
  final CarGroup group;
  final int? selectedSztuka;
  final VoidCallback onCancel;
  final VoidCallback? onSuccess;

  const BookingFlow({
    super.key,
    required this.group,
    required this.selectedSztuka,
    required this.onCancel,
    this.onSuccess,
  });

  @override
  State<BookingFlow> createState() => _BookingFlowState();
}

class _BookingFlowState extends State<BookingFlow>
    with SingleTickerProviderStateMixin {

  int _step = 0; // 0 = data podpisania, 1 = okres najmu, 2 = potwierdzenie

  // Krok 1
  DateTime? _signingDate;
  int? _signingHour;

  // Krok 2
  int _days = 1;

  // Historia wypożyczeń auta
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;

  // Animacja
  late final AnimationController _animCtrl;
  late final Animation<double> _fade;

  // Dostępne godziny podpisania (8:00 - 16:00 co godzinę)
  static const _hours = [8, 9, 10, 11, 12, 13, 14, 15, 16];

  // Miesiące kalendarza
  late DateTime _calMonth;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _calMonth = DateTime.now();
    _loadHistory();
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      // Pobierz ID egzemplarzy tego modelu
      final carIds = widget.group.sztuki
          .map((s) => s['id'] as int)
          .toList();

      final res = await Supabase.instance.client
          .from('wypozyczenia')
          .select('id_samochodu, data_rozpoczecia, data_zakonczenia, status, liczba_dni, cena_calkowita')
          .inFilter('id_samochodu', carIds)
          .order('data_rozpoczecia', ascending: false);

      if (mounted) setState(() {
        _history = (res as List).cast<Map<String, dynamic>>();
        _loadingHistory = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  // Minimalna data podpisania = dziś + 3 dni robocze (bez niedziel)
  DateTime get _minSigningDate {
    var d = DateTime.now();
    int added = 0;
    while (added < 3) {
      d = d.add(const Duration(days: 1));
      if (d.weekday != DateTime.sunday) added++;
    }
    return DateTime(d.year, d.month, d.day);
  }

  // Czy data jest zablokowana (niedziela lub zajęta)
  bool _isBlocked(DateTime day) {
    if (day.weekday == DateTime.sunday) return true;
    if (day.isBefore(_minSigningDate)) return true;
    return false;
  }

  // Czy data ma aktywne wypożyczenie
  bool _isOccupied(DateTime day) {
    for (final h in _history) {
      final start = DateTime.parse(h['data_rozpoczecia']);
      final end   = DateTime.parse(h['data_zakonczenia']);
      if (!day.isBefore(start) && !day.isAfter(end)) {
        if (h['status'] == 'aktywne' || h['status'] == 'zakonczone') {
          return true;
        }
      }
    }
    return false;
  }

  // Oblicz cenę na podstawie liczby dni
  double _calcPrice(int days) {
    final cennik = widget.group.cennik;
    if (cennik.isEmpty) return widget.group.kaucja / 5 * days;
    for (final c in cennik) {
      final min = c['min_dni'] as int;
      final max = c['max_dni'] as int;
      if (days >= min && days <= max) {
        return (c['cena_za_dobe'] as num).toDouble() * days;
      }
    }
    return (cennik.last['cena_za_dobe'] as num).toDouble() * days;
  }

  double _getPricePerDay(int days) {
    final cennik = widget.group.cennik;
    if (cennik.isEmpty) return widget.group.kaucja / 5;
    for (final c in cennik) {
      final min = c['min_dni'] as int;
      final max = c['max_dni'] as int;
      if (days >= min && days <= max) {
        return (c['cena_za_dobe'] as num).toDouble();
      }
    }
    return (cennik.last['cena_za_dobe'] as num).toDouble();
  }

  double get _basePrice {
    final cennik = widget.group.cennik;
    if (cennik.isEmpty) return widget.group.kaucja / 5;
    return (cennik.first['cena_za_dobe'] as num).toDouble();
  }

  int _discountPercent(int days) {
    final base = _basePrice;
    final actual = _getPricePerDay(days);
    if (base <= 0) return 0;
    return ((1 - actual / base) * 100).round();
  }

  Future<void> _nextStep() async {
    await _animCtrl.reverse();
    setState(() => _step++);
    _animCtrl.forward();
  }

  Future<void> _prevStep() async {
    await _animCtrl.reverse();
    setState(() => _step--);
    _animCtrl.forward();
  }

  Future<void> _confirm() async {
    // Zapisz wypożyczenie do Supabase
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _signingDate == null) return;

    final carId = widget.selectedSztuka
        ?? widget.group.sztuki.firstWhere(
            (s) => s['status'] == 'dostepny')['id'] as int;

    final startDate = _signingDate!;
    final endDate = startDate.add(Duration(days: _days));
    final cenaZaDobe = _getPricePerDay(_days);
    final cenaCal = _calcPrice(_days);

    try {
      await Supabase.instance.client.from('wypozyczenia').insert({
        'id_uzytkownika': user.id,
        'id_samochodu': carId,
        'liczba_dni': _days,
        'cena_za_dobe': cenaZaDobe,
        'cena_calkowita': cenaCal,
        'kaucja': widget.group.kaucja,
        'status': 'aktywne',
        'data_rozpoczecia': startDate.toIso8601String(),
        'data_zakonczenia': endDate.toIso8601String(),
      });

      // Zaktualizuj status samochodu na niedostepny
      await Supabase.instance.client
          .from('samochody')
          .update({'status': 'niedostepny'})
          .eq('id', carId);

      // Najpierw pokaż ekran sukcesu
      await _animCtrl.reverse();
      setState(() => _step = 2);
      _animCtrl.forward();

      // Odśwież listę w tle
      widget.onSuccess?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Błąd: $e'),
          backgroundColor: const Color(0xFF332222)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stepper
          _Stepper(step: _step),
          const SizedBox(height: 20),

          // Zawartość kroku
          if (_step == 0) _buildStep0(),
          if (_step == 1) _buildStep1(),
          if (_step == 2) _buildStep2(),
        ],
      ),
    );
  }

  // ── KROK 0: Wybór daty podpisania umowy ──────────────────────────────
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(
          title: 'Data podpisania umowy',
          subtitle: 'Wybierz termin wizyty w naszym biurze'),
        const SizedBox(height: 16),

        // Informacja o minimalnym terminie
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFF44440A).withOpacity(0.5), width: 1)),
          child: Row(children: [
            const Icon(Icons.info_outline,
                color: Color(0xFFAAAA44), size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Minimalny czas oczekiwania to 3 dni robocze (nie licząc niedziel) '
              'na przygotowanie umowy, kaucji i dokumentacji.',
              style: const TextStyle(color: Color(0xFF999944),
                  fontSize: 11, fontWeight: FontWeight.w300, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 16),

        // Kalendarz
        _Calendar(
          month: _calMonth,
          selected: _signingDate,
          minDate: _minSigningDate,
          isBlocked: _isBlocked,
          isOccupied: _isOccupied,
          history: _history,
          fleetDate: null,
          onMonthChanged: (m) => setState(() => _calMonth = m),
          onDaySelected: (d) => setState(() {
            _signingDate = d;
            _signingHour = null;
          }),
        ),

        if (_signingDate != null) ...[
          const SizedBox(height: 16),
          const Text('Godzina wizyty', style: TextStyle(
            color: C.text, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8,
            children: _hours.map((h) {
              final sel = _signingHour == h;
              return GestureDetector(
                onTap: () => setState(() => _signingHour = h),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.white : C.field,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel
                          ? Colors.white : C.fieldBorder,
                      width: 1)),
                  child: Text('${h.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      color: sel ? Colors.black : C.textSub,
                      fontSize: 12, fontWeight: FontWeight.w500))),
              );
            }).toList()),
        ],

        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _FlowBtn(
            label: '← Anuluj',
            primary: false,
            enabled: true,
            onTap: widget.onCancel)),
          const SizedBox(width: 12),
          Expanded(child: _FlowBtn(
            label: 'Dalej →',
            primary: true,
            enabled: _signingDate != null && _signingHour != null,
            onTap: _nextStep)),
        ]),
      ],
    );
  }

  // ── KROK 1: Okres najmu ───────────────────────────────────────────────
  Widget _buildStep1() {
    final price    = _calcPrice(_days);
    final perDay   = _getPricePerDay(_days);
    final discount = _discountPercent(_days);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          title: 'Okres wynajmu',
          subtitle: 'Od ${_formatDate(_signingDate!)} '
              '${_signingHour!.toString().padLeft(2,'0')}:00'),
        const SizedBox(height: 16),

        // Suwak dni
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Liczba dób', style: TextStyle(
              color: C.textMuted, fontSize: 10,
              fontWeight: FontWeight.w600, letterSpacing: 1.2)),
            const Spacer(),
            Text('$_days ${_days == 1 ? "doba" : (_days < 5 ? "doby" : "dób")}',
              style: const TextStyle(color: C.text,
                  fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: C.fieldBorder,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.08),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 2,
            ),
            child: Slider(
              value: _days.toDouble(),
              min: 1, max: 30, divisions: 29,
              onChanged: (v) => setState(() => _days = v.round()),
            ),
          ),
        ]),

        const SizedBox(height: 16),

        // Przedziały cennikowe z podświetleniem
        const Text('Dostępne przedziały cenowe', style: TextStyle(
          color: C.text, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...widget.group.cennik.map((c) {
          final min = c['min_dni'] as int;
          final max = c['max_dni'] as int;
          final p   = (c['cena_za_dobe'] as num).toDouble();
          final disc = _discountForRange(min);
          final active = _days >= min && _days <= max;
          final isNext = _days < min; // zachęta

          return MouseRegion(
            cursor: isNext ? SystemMouseCursors.click : MouseCursor.defer,
            child: GestureDetector(
              onTap: isNext
                  ? () => setState(() => _days = min) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withOpacity(0.07)
                      : (isNext ? const Color(0xFF0F1A0F) : C.field),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active
                        ? Colors.white.withOpacity(0.25)
                        : (isNext
                            ? const Color(0xFF2A4A2A)
                            : C.fieldBorder),
                    width: 1)),
                child: Row(children: [
                  // Zakres
                  Text('$min–$max dób',
                    style: TextStyle(
                      color: active ? C.text : C.textSub,
                      fontSize: 12, fontWeight: FontWeight.w400)),
                  const SizedBox(width: 10),
                  // Zachęta
                  if (isNext)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3A1A),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: const Color(0xFF2A5A2A), width: 1)),
                      child: Text('Kliknij → taniej!',
                        style: const TextStyle(
                          color: Color(0xFF66BB66), fontSize: 9,
                          fontWeight: FontWeight.w600))),
                  const Spacer(),
                  // Cena
                  Text('${p.toInt()} zł/dobę',
                    style: TextStyle(
                      color: active ? C.text : C.textSub,
                      fontSize: 12, fontWeight: FontWeight.w400)),
                  const SizedBox(width: 8),
                  // Zniżka
                  if (disc > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: C.success.withOpacity(
                            active ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: C.success.withOpacity(
                              active ? 0.4 : 0.2),
                          width: 1)),
                      child: Text('−$disc%',
                        style: TextStyle(
                          color: C.success.withOpacity(
                              active ? 1.0 : 0.5),
                          fontSize: 10, fontWeight: FontWeight.w700))),
                ]),
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Podsumowanie ceny
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: C.field,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.fieldBorder, width: 1)),
          child: Column(children: [
            _PriceRow('Cena za dobę', '${perDay.toInt()} zł'),
            _PriceRow('Liczba dób', '$_days'),
            if (discount > 0)
              _PriceRow('Zniżka', '−$discount%',
                  color: C.success),
            const Divider(color: C.divider, height: 16),
            _PriceRow('Łącznie', '${price.toInt()} zł',
                big: true),
            _PriceRow('Kaucja zwrotna',
                '${widget.group.kaucja.toInt()} zł',
                color: C.textSub),
          ]),
        ),

        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _FlowBtn(
            label: '← Wróć',
            primary: false,
            enabled: true,
            onTap: _prevStep)),
          const SizedBox(width: 12),
          Expanded(child: _FlowBtn(
            label: 'Potwierdź →',
            primary: true,
            enabled: true,
            onTap: _confirm)),
        ]),
      ],
    );
  }

  // ── KROK 2: Potwierdzenie ─────────────────────────────────────────────
  Widget _buildStep2() {
    final endDate = _signingDate!.add(Duration(days: _days));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: C.success.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: C.success.withOpacity(0.4), width: 1)),
          child: const Icon(Icons.check_rounded,
              color: C.success, size: 30)),
        const SizedBox(height: 16),
        const Text('Rezerwacja potwierdzona!',
          style: TextStyle(color: C.text, fontSize: 17,
              fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Zapraszamy do biura ${_formatDate(_signingDate!)} '
          'o godz. ${_signingHour!.toString().padLeft(2,'0')}:00\n'
          'w celu podpisania umowy i odbioru kluczyków.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: C.textSub, fontSize: 13,
              fontWeight: FontWeight.w300, height: 1.6)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.field,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.fieldBorder, width: 1)),
          child: Column(children: [
            _PriceRow('Auto',
                '${widget.group.marka} ${widget.group.model}'),
            _PriceRow('Podpisanie umowy',
                '${_formatDate(_signingDate!)} '
                '${_signingHour!.toString().padLeft(2,'0')}:00'),
            _PriceRow('Okres najmu',
                '${_formatDate(_signingDate!)} – ${_formatDate(endDate)}'),
            _PriceRow('Liczba dób', '$_days'),
            const Divider(color: C.divider, height: 14),
            _PriceRow('Do zapłaty', '${_calcPrice(_days).toInt()} zł',
                big: true),
            _PriceRow('Kaucja', '${widget.group.kaucja.toInt()} zł',
                color: C.textSub),
          ]),
        ),
        const SizedBox(height: 20),
        _FlowBtn(
          label: 'Zamknij',
          primary: true,
          enabled: true,
          onTap: widget.onCancel),
      ],
    );
  }

  int _discountForRange(int minDni) {
    final cennik = widget.group.cennik;
    for (final c in cennik) {
      if (c['min_dni'] == minDni) {
        final base = (cennik.first['cena_za_dobe'] as num).toDouble();
        final curr = (c['cena_za_dobe'] as num).toDouble();
        if (base <= 0) return 0;
        return ((1 - curr / base) * 100).round();
      }
    }
    return 0;
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
}

// ═══════════════════════════════════════════════════════════════════════
// KALENDARZ
// ═══════════════════════════════════════════════════════════════════════
class _Calendar extends StatelessWidget {
  final DateTime month;
  final DateTime? selected;
  final DateTime minDate;
  final bool Function(DateTime) isBlocked;
  final bool Function(DateTime) isOccupied;
  final List<Map<String, dynamic>> history;
  final DateTime? fleetDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  const _Calendar({
    required this.month,
    required this.selected,
    required this.minDate,
    required this.isBlocked,
    required this.isOccupied,
    required this.history,
    required this.fleetDate,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Offset: poniedziałek = 0
    int offset = firstDay.weekday - 1;

    return Container(
      decoration: BoxDecoration(
        color: C.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.fieldBorder, width: 1)),
      child: Column(children: [
        // Nawigacja miesiąca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(children: [
            Text(
              '${_monthName(month.month)} ${month.year}',
              style: const TextStyle(color: C.text, fontSize: 13,
                  fontWeight: FontWeight.w600)),
            const Spacer(),
            _CalNavBtn(
              icon: Icons.chevron_left,
              onTap: () => onMonthChanged(
                  DateTime(month.year, month.month - 1)),
            ),
            _CalNavBtn(
              icon: Icons.chevron_right,
              onTap: () => onMonthChanged(
                  DateTime(month.year, month.month + 1)),
            ),
          ]),
        ),

        // Nagłówki dni
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: ['Pn','Wt','Śr','Cz','Pt','So','Nd']
              .map((d) => Expanded(child: Center(
                child: Text(d, style: const TextStyle(
                  color: C.textMuted, fontSize: 10,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)))))
              .toList()),
        ),
        const SizedBox(height: 4),

        // Siatka dni
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, childAspectRatio: 1.2),
            itemCount: offset + daysInMonth,
            itemBuilder: (_, i) {
              if (i < offset) return const SizedBox.shrink();
              final day = DateTime(month.year, month.month, i - offset + 1);
              final today = DateTime.now();
              final isToday = day.year == today.year &&
                  day.month == today.month && day.day == today.day;
              final blocked  = isBlocked(day);
              final occupied = isOccupied(day);
              final isSel    = selected != null &&
                  day.year == selected!.year &&
                  day.month == selected!.month &&
                  day.day == selected!.day;
              final isSunday = day.weekday == DateTime.sunday;

              return GestureDetector(
                onTap: blocked || occupied ? null
                    : () => onDaySelected(day),
                child: MouseRegion(
                  cursor: blocked || occupied
                      ? SystemMouseCursors.forbidden
                      : SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSel
                          ? Colors.white
                          : (occupied
                              ? const Color(0xFF2A1A1A)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(6),
                      border: isToday && !isSel
                          ? Border.all(
                              color: Colors.white.withOpacity(0.3), width: 1)
                          : null),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${i - offset + 1}',
                          style: TextStyle(
                            color: isSel
                                ? Colors.black
                                : (blocked
                                    ? (isSunday
                                        ? const Color(0xFF442222)
                                        : C.textMuted.withOpacity(0.4))
                                    : (occupied
                                        ? const Color(0xFF884444)
                                        : C.text)),
                            fontSize: 11,
                            fontWeight: isSel
                                ? FontWeight.w700 : FontWeight.w400)),
                        if (occupied)
                          Container(width: 4, height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFF884444),
                              shape: BoxShape.circle)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Legenda
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            _LegendDot(color: const Color(0xFF884444),
                label: 'Zajęte'),
            const SizedBox(width: 16),
            _LegendDot(color: const Color(0xFF442222),
                label: 'Niedziela'),
            const SizedBox(width: 16),
            _LegendDot(color: Colors.white, label: 'Wybrane'),
          ]),
        ),

        // Historia wypożyczeń
        if (history.isNotEmpty) ...[
          Container(height: 1, color: C.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              const Icon(Icons.history, color: C.textMuted, size: 13),
              const SizedBox(width: 6),
              const Text('Historia wypożyczeń', style: TextStyle(
                color: C.textSub, fontSize: 11,
                fontWeight: FontWeight.w600)),
            ]),
          ),
          ...history.take(5).map((h) {
            final start = DateTime.parse(h['data_rozpoczecia']);
            final end   = DateTime.parse(h['data_zakonczenia']);
            final status = h['status'] as String;
            final color = status == 'aktywne'
                ? C.success
                : (status == 'zakonczone'
                    ? C.textSub : const Color(0xFF884444));
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(children: [
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                  '${_fmt(start)} – ${_fmt(end)}',
                  style: const TextStyle(color: C.textSub,
                      fontSize: 11, fontWeight: FontWeight.w300)),
                const Spacer(),
                Text(status, style: TextStyle(
                  color: color, fontSize: 10,
                  fontWeight: FontWeight.w500)),
              ]),
            );
          }),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }

  String _monthName(int m) => const [
    'Styczeń','Luty','Marzec','Kwiecień','Maj','Czerwiec',
    'Lipiec','Sierpień','Wrzesień','Październik','Listopad','Grudzień'
  ][m - 1];

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
}

class _CalNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CalNavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: C.field,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: C.fieldBorder, width: 1)),
        child: Icon(icon, color: C.textSub, size: 16)),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: C.textMuted,
        fontSize: 10, fontWeight: FontWeight.w300)),
  ]);
}

// ── POMOCNICZE ────────────────────────────────────────────────────────
class _Stepper extends StatelessWidget {
  final int step;
  const _Stepper({required this.step});

  static const _labels = ['Data podpisania', 'Okres najmu', 'Potwierdzenie'];

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(3, (i) {
      final done   = i < step;
      final active = i == step;
      return Expanded(child: Row(children: [
        if (i > 0) Expanded(child: Container(
          height: 1,
          color: done ? Colors.white.withOpacity(0.4) : C.fieldBorder)),
        Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: active ? Colors.white
                  : (done ? Colors.white.withOpacity(0.15)
                      : C.field),
              shape: BoxShape.circle,
              border: Border.all(
                color: active || done
                    ? Colors.white.withOpacity(0.5) : C.fieldBorder,
                width: 1)),
            child: Center(child: done
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : Text('${i + 1}', style: TextStyle(
                    color: active ? Colors.black : C.textMuted,
                    fontSize: 10, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 4),
          Text(_labels[i], style: TextStyle(
            color: active ? C.text : C.textMuted,
            fontSize: 9, fontWeight: FontWeight.w400)),
        ]),
        if (i < 2) Expanded(child: Container(
          height: 1,
          color: done ? Colors.white.withOpacity(0.4) : C.fieldBorder)),
      ]));
    }),
  );
}

class _StepTitle extends StatelessWidget {
  final String title, subtitle;
  const _StepTitle({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: C.text,
          fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(subtitle, style: const TextStyle(color: C.textSub,
          fontSize: 12, fontWeight: FontWeight.w300)),
    ],
  );
}

class _PriceRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  final bool big;
  const _PriceRow(this.label, this.value, {this.color, this.big = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(
        color: C.textSub, fontSize: big ? 13 : 12,
        fontWeight: big ? FontWeight.w600 : FontWeight.w300))),
      Text(value, style: TextStyle(
        color: color ?? (big ? C.text : C.text),
        fontSize: big ? 14 : 12,
        fontWeight: big ? FontWeight.w700 : FontWeight.w400)),
    ]),
  );
}

class _FlowBtn extends StatefulWidget {
  final String label;
  final bool primary, enabled;
  final VoidCallback onTap;
  const _FlowBtn({required this.label, required this.primary,
      required this.enabled, required this.onTap});
  @override
  State<_FlowBtn> createState() => _FlowBtnState();
}

class _FlowBtnState extends State<_FlowBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.enabled
        ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 46,
        decoration: BoxDecoration(
          color: widget.primary
              ? (widget.enabled
                  ? (_hovered ? const Color(0xFFEEEEEE) : Colors.white)
                  : const Color(0xFF333333))
              : (_hovered ? const Color(0xFF1E1E1E) : C.field),
          borderRadius: BorderRadius.circular(10),
          border: widget.primary ? null
              : Border.all(color: C.fieldBorder, width: 1)),
        child: Center(child: Text(widget.label, style: TextStyle(
          color: widget.primary
              ? (widget.enabled ? Colors.black : C.textMuted)
              : C.textSub,
          fontSize: 12, fontWeight: FontWeight.w600,
          letterSpacing: 1.5))),
      ),
    ),
  );
}