import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cars_page.dart' show assetForModel, C, CarGroup, AvailBadge, CarDetail;

// ═══════════════════════════════════════════════════════════════════════
// STRONA WYSZUKIWANIA
// ═══════════════════════════════════════════════════════════════════════
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {

  // Dane z bazy
  List<Map<String, dynamic>> _allCars = [];
  List<String>               _marki   = [];
  Map<String, List<String>>  _modele  = {};
  bool _loadingData = true;

  // Filtry
  String? _marka;
  String? _model;
  RangeValues _rok      = const RangeValues(2018, 2023);
  RangeValues _moc      = const RangeValues(70, 700);
  RangeValues _spal     = const RangeValues(4, 18);
  RangeValues _poj      = const RangeValues(0.8, 6.5);
  String? _naped;
  String? _rodzaj;
  String? _kolor;

  static const _napedy  = ['FWD', 'RWD', 'AWD', '4x4'];
  static const _rodzaje = ['sedan', 'SUV', 'hatchback', 'kombi',
      'coupe', 'cabrio', 'van'];
  static const _kolory  = ['biały', 'czarny', 'szary', 'czerwony',
      'niebieski', 'granatowy', 'żółty', 'pomarańczowy'];

  // Wyniki
  List<CarGroup> _results = [];
  bool _searched  = false;
  bool _searching = false;

  // Animacja wyników
  late final AnimationController _resultsAnim;
  late final Animation<double>   _resultsFade;

  @override
  void initState() {
    super.initState();
    _resultsAnim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400));
    _resultsFade = CurvedAnimation(
        parent: _resultsAnim, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _resultsAnim.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final res = await Supabase.instance.client
          .from('samochody')
          .select('''
            id, id_modelu, rok_produkcji, numer_rejestracyjny, moc_km, pojemnosc_silnika,
            srednie_spalanie, przebieg, naped, rodzaj, kolor,
            kaucja, status, opis_krotki, url_modelu_3d,
            modele ( nazwa, marki ( nazwa ) ),
            cennik ( min_dni, max_dni, cena_za_dobe )
          ''');

      final list = (res as List).cast<Map<String, dynamic>>();

      // Zbierz unikalne marki i modele
      final markiSet = <String>{};
      final modeleMap = <String, List<String>>{};
      for (final car in list) {
        try {
          final m = car['modele']['marki']['nazwa'] as String;
          final mo = car['modele']['nazwa'] as String;
          markiSet.add(m);
          modeleMap.putIfAbsent(m, () => []);
          if (!modeleMap[m]!.contains(mo)) modeleMap[m]!.add(mo);
        } catch (_) {}
      }

      if (mounted) setState(() {
        _allCars    = list;
        _marki      = markiSet.toList()..sort();
        _modele     = modeleMap;
        _loadingData = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _search({bool showAll = false}) async {
    setState(() => _searching = true);
    _resultsAnim.reset();

    await Future.delayed(const Duration(milliseconds: 100));

    List<Map<String, dynamic>> filtered = _allCars.where((car) {
      if (showAll) return true;

      // Marka
      if (_marka != null) {
        try {
          if (car['modele']['marki']['nazwa'] != _marka) return false;
        } catch (_) { return false; }
      }
      // Model
      if (_model != null) {
        try {
          if (car['modele']['nazwa'] != _model) return false;
        } catch (_) { return false; }
      }
      // Rok
      final rok = car['rok_produkcji'] as int;
      if (rok < _rok.start || rok > _rok.end) return false;
      // Moc
      final moc = car['moc_km'] as int;
      if (moc < _moc.start || moc > _moc.end) return false;
      // Spalanie
      final spal = (car['srednie_spalanie'] as num).toDouble();
      if (spal < _spal.start || spal > _spal.end) return false;
      // Pojemność
      final poj = (car['pojemnosc_silnika'] as num).toDouble();
      if (poj < _poj.start || poj > _poj.end) return false;
      // Napęd
      if (_naped != null && car['naped'] != _naped) return false;
      // Rodzaj
      if (_rodzaj != null && car['rodzaj'] != _rodzaj) return false;
      // Kolor
      if (_kolor != null && car['kolor'] != _kolor) return false;

      return true;
    }).toList();

    // Grupuj po modelu
    final groups = _buildGroups(filtered);

    if (mounted) {
      setState(() {
        _results  = groups;
        _searched = true;
        _searching = false;
      });
      _resultsAnim.forward();
    }
  }

  List<CarGroup> _buildGroups(List<Map<String, dynamic>> cars) {
    final Map<int, List<Map<String, dynamic>>> byModel = {};
    for (final car in cars) {
      final mid = car['id_modelu'] as int;
      byModel.putIfAbsent(mid, () => []).add(car);
    }
    final groups = <CarGroup>[];
    for (final entry in byModel.entries) {
      final sztuki = entry.value;
      final first  = sztuki.first;
      double minCena = double.maxFinite;
      for (final s in sztuki) {
        for (final c in (s['cennik'] as List? ?? [])) {
          final p = (c['cena_za_dobe'] as num).toDouble();
          if (p < minCena) minCena = p;
        }
      }
      final cennik = List<Map>.from(first['cennik'] as List? ?? [])
        ..sort((a, b) => (a['min_dni'] as int).compareTo(b['min_dni'] as int));
      groups.add(CarGroup(
        modelId:   entry.key,
        marka:     _s(first, ['modele', 'marki', 'nazwa']),
        model:     _s(first, ['modele', 'nazwa']),
        rodzaj:    first['rodzaj'] as String? ?? '',
        opis:      first['opis_krotki'] as String? ?? '',
        rok:       first['rok_produkcji'] as int,
        mocKm:     first['moc_km'] as int,
        pojemnosc: (first['pojemnosc_silnika'] as num).toDouble(),
        spalanie:  (first['srednie_spalanie'] as num).toDouble(),
        naped:     first['naped'] as String? ?? '',
        zdjecie:   first['url_modelu_3d'] as String?,
        minCena:   minCena == double.maxFinite ? 0 : minCena,
        dostepne:  sztuki.where((s) => s['status'] == 'dostepny').length,
        wszystkie: sztuki.length,
        cennik:    cennik.cast<Map<String, dynamic>>(),
        kaucja:    (first['kaucja'] as num).toDouble(),
        sztuki:    sztuki,
      ));
    }
    return groups;
  }

  String _s(Map m, List<String> keys) {
    try {
      dynamic v = m;
      for (final k in keys) v = v[k];
      return v as String;
    } catch (_) { return '—'; }
  }

  void _reset() {
    setState(() {
      _marka = null; _model = null;
      _rok   = const RangeValues(2018, 2023);
      _moc   = const RangeValues(70, 700);
      _spal  = const RangeValues(4, 18);
      _poj   = const RangeValues(0.8, 6.5);
      _naped = null; _rodzaj = null; _kolor = null;
      _searched = false; _results = [];
    });
    _resultsAnim.reset();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final pad = isMobile ? 16.0 : 40.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, isMobile ? 20 : 32, pad, pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nagłówek
          Text('Wyszukaj auto', style: TextStyle(
            color: C.text, fontSize: isMobile ? 22 : 26,
            fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          const Text('Znajdź idealne auto dopasowane do Twoich potrzeb',
            style: TextStyle(color: C.textSub, fontSize: 13,
                fontWeight: FontWeight.w300)),
          const SizedBox(height: 20),

          // Karta filtrów
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 28),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.cardBorder, width: 1)),
            child: _loadingData
                ? const Center(
                    heightFactor: 3,
                    child: CircularProgressIndicator(
                        color: Color(0xFF555555), strokeWidth: 1.5))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rząd 1: Marka + Model
                      _Row2(children: [
                        _DropField(
                          label: 'MARKA',
                          value: _marka,
                          items: _marki,
                          hint: 'Wszystkie',
                          onChanged: (v) => setState(() {
                            _marka = v; _model = null;
                          }),
                        ),
                        _DropField(
                          label: 'MODEL',
                          value: _model,
                          items: _marka != null
                              ? (_modele[_marka] ?? []) : [],
                          hint: _marka == null
                              ? 'Najpierw wybierz markę' : 'Wszystkie modele',
                          disabled: _marka == null,
                          onChanged: (v) => setState(() => _model = v),
                        ),
                      ]),
                      const SizedBox(height: 22),

                      // Rząd 2: Rocznik + Moc
                      _Row2(children: [
                        _RangeField(
                          label: 'ROCZNIK',
                          values: _rok,
                          min: 2015, max: 2023, divisions: 8,
                          format: (v) => v.toInt().toString(),
                          onChanged: (v) => setState(() => _rok = v),
                        ),
                        _RangeField(
                          label: 'MOC (KM)',
                          values: _moc,
                          min: 70, max: 700, divisions: 63,
                          format: (v) => '${v.toInt()} KM',
                          onChanged: (v) => setState(() => _moc = v),
                        ),
                      ]),
                      const SizedBox(height: 22),

                      // Rząd 3: Spalanie + Pojemność
                      _Row2(children: [
                        _RangeField(
                          label: 'SPALANIE (l/100km)',
                          values: _spal,
                          min: 4, max: 18, divisions: 14,
                          format: (v) => '${v.toStringAsFixed(1)} l',
                          onChanged: (v) => setState(() => _spal = v),
                        ),
                        _RangeField(
                          label: 'POJEMNOŚĆ (l)',
                          values: _poj,
                          min: 0.8, max: 6.5, divisions: 57,
                          format: (v) => '${v.toStringAsFixed(1)} l',
                          onChanged: (v) => setState(() => _poj = v),
                        ),
                      ]),
                      const SizedBox(height: 22),

                      // Rząd 4: Rodzaj + Napęd + Kolor
                      _Row3(children: [
                        _DropField(
                          label: 'RODZAJ',
                          value: _rodzaj,
                          items: _rodzaje,
                          hint: 'Dowolny',
                          onChanged: (v) => setState(() => _rodzaj = v),
                        ),
                        _DropField(
                          label: 'NAPĘD',
                          value: _naped,
                          items: _napedy,
                          hint: 'Dowolny',
                          onChanged: (v) => setState(() => _naped = v),
                        ),
                        _DropField(
                          label: 'KOLOR',
                          value: _kolor,
                          items: _kolory,
                          hint: 'Dowolny',
                          onChanged: (v) => setState(() => _kolor = v),
                        ),
                      ]),
                      const SizedBox(height: 28),

                      // Przyciski
                      Row(children: [
                        Expanded(child: _SearchBtn(
                          label: 'SZUKAJ',
                          primary: true,
                          loading: _searching,
                          onTap: () => _search(),
                        )),
                        const SizedBox(width: 12),
                        _ResetBtn(onTap: _reset),
                      ]),
                    ],
                  ),
          ),

          // Wyniki
          if (_searched) ...[
            const SizedBox(height: 36),
            FadeTransition(
              opacity: _resultsFade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      _results.isEmpty
                          ? 'Brak wyników'
                          : 'Znaleziono ${_results.length} ${_results.length == 1 ? "model" : "modeli"}',
                      style: const TextStyle(color: C.text, fontSize: 18,
                          fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                    if (_results.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: C.field,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: C.fieldBorder, width: 1)),
                        child: Text(
                          '${_results.fold<int>(0, (s, g) => s + g.wszystkie)} szt.',
                          style: const TextStyle(color: C.textSub,
                              fontSize: 11))),
                    ],
                  ]),
                  const SizedBox(height: 20),
                  if (_results.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: C.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.cardBorder, width: 1)),
                      child: const Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off,
                              color: C.textMuted, size: 36),
                          SizedBox(height: 12),
                          Text('Nie znaleziono aut spełniających kryteria',
                            style: TextStyle(color: C.textSub,
                                fontSize: 14, fontWeight: FontWeight.w300)),
                        ],
                      )))
                  else
                    LayoutBuilder(builder: (_, c) {
                      final isMobile = c.maxWidth < 500;
                      final cols = isMobile ? 2
                          : (c.maxWidth > 1100 ? 4 : 3);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: isMobile ? 8 : 12,
                          mainAxisSpacing: isMobile ? 8 : 12,
                          childAspectRatio: isMobile ? 0.56 : 0.70),
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) =>
                            _SearchTile(group: _results[i]),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// KAFELEK WYNIKOWY (kopia z cars_page ale niezależna)
// ═══════════════════════════════════════════════════════════════════════
class _SearchTile extends StatefulWidget {
  final CarGroup group;
  const _SearchTile({required this.group});
  @override
  State<_SearchTile> createState() => _SearchTileState();
}

class _SearchTileState extends State<_SearchTile> {
  bool _hovered = false;
  CarGroup get g => widget.group;

  @override
  Widget build(BuildContext context) {
    final opisShort = g.opis.length > 70
        ? '${g.opis.substring(0, 67)}...' : g.opis;
    final asset = assetForModel(g.model);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: '',
          barrierColor: Colors.black.withOpacity(0.75),
          transitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, __, ___) => CarDetail(group: g),
          transitionBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(0, 0.04), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
              child: child)),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1A1A1A) : C.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? const Color(0xFF333333) : C.cardBorder,
              width: 1)),
          child: Opacity(
            opacity: g.dostepne > 0 ? 1.0 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zdjęcie
                Expanded(flex: 8,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13)),
                    child: asset != null
                        ? Container(
                            width: double.infinity,
                            color: const Color(0xFF0F0F0F),
                            child: Stack(children: [
                              Positioned.fill(child: Transform.scale(
                                scale: 1.6,
                                child: Image.asset(asset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.directions_car_outlined,
                                          color: Color(0xFF252525), size: 46)))),
                              Positioned(top: 10, left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.06),
                                        width: 1)),
                                  child: Text(g.rodzaj, style: const TextStyle(
                                    color: C.textSub, fontSize: 9,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.4)))),
                            ]))
                        : _buildPlaceholder(),
                  ),
                ),
                // Dane
                Expanded(flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${g.marka} ${g.model}',
                          style: const TextStyle(color: C.text,
                              fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('${g.rok} · ${g.mocKm} KM',
                          style: const TextStyle(color: C.textMuted,
                              fontSize: 11, fontWeight: FontWeight.w300)),
                        if (opisShort.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(opisShort,
                            style: const TextStyle(color: C.textSub,
                                fontSize: 10, fontWeight: FontWeight.w300,
                                height: 1.4),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                        const Spacer(),
                        Row(children: [
                          Expanded(child: Text(
                            g.minCena > 0
                                ? 'od ${g.minCena.toInt()} zł / dobę'
                                : 'Wycena',
                            style: const TextStyle(color: C.text,
                                fontSize: 11, fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                          AvailBadge(
                              dostepne: g.dostepne,
                              wszystkie: g.wszystkie,
                              dostepneOd: g.dostepneOd),
                        ]),
                      ],
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

  Widget _buildPlaceholder() => Container(
    width: double.infinity,
    color: const Color(0xFF0F0F0F),
    child: Stack(children: [
      Center(child: Icon(
        g.rodzaj == 'van' ? Icons.airport_shuttle_outlined
            : g.rodzaj == 'cabrio' ? Icons.wb_sunny_outlined
            : Icons.directions_car_outlined,
        size: 46, color: const Color(0xFF252525))),
      Positioned(top: 10, left: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(5)),
          child: Text(g.rodzaj, style: const TextStyle(
            color: C.textSub, fontSize: 9)))),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// POMOCNICZE WIDGETY FILTRÓW
// ═══════════════════════════════════════════════════════════════════════
class _Row2 extends StatelessWidget {
  final List<Widget> children;
  const _Row2({required this.children});
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          children[0],
          const SizedBox(height: 14),
          children[1],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 20),
        Expanded(child: children[1]),
      ],
    );
  }
}

class _Row3 extends StatelessWidget {
  final List<Widget> children;
  const _Row3({required this.children});
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          children[0],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: children[1]),
            const SizedBox(width: 12),
            Expanded(child: children[2]),
          ]),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 16),
        Expanded(child: children[1]),
        const SizedBox(width: 16),
        Expanded(child: children[2]),
      ],
    );
  }
}

class _DropField extends StatelessWidget {
  final String label;
  final String? value;
  final List items;
  final String hint;
  final bool disabled;
  final ValueChanged<String?> onChanged;

  const _DropField({
    required this.label, required this.value, required this.items,
    required this.hint, required this.onChanged, this.disabled = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
        color: C.textMuted, fontSize: 10,
        fontWeight: FontWeight.w600, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: disabled
              ? C.field.withOpacity(0.5) : C.field,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.fieldBorder, width: 1)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(hint, style: TextStyle(
              color: disabled ? C.textMuted.withOpacity(0.4) : C.textMuted,
              fontSize: 13, fontWeight: FontWeight.w300)),
            isExpanded: true,
            dropdownColor: const Color(0xFF1A1A1A),
            icon: Icon(Icons.keyboard_arrow_down,
              color: disabled
                  ? C.textMuted.withOpacity(0.3) : C.textMuted, size: 18),
            style: const TextStyle(color: C.text, fontSize: 13),
            items: disabled ? [] : [
              DropdownMenuItem<String>(
                value: null,
                child: Text('Wszystkie', style: const TextStyle(
                    color: C.textMuted, fontSize: 13))),
              ...items.map((i) => DropdownMenuItem(
                  value: i as String, child: Text(i))),
            ],
            onChanged: disabled ? null : onChanged,
          ),
        ),
      ),
    ],
  );
}

class _RangeField extends StatelessWidget {
  final String label;
  final RangeValues values;
  final double min, max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<RangeValues> onChanged;

  const _RangeField({
    required this.label, required this.values, required this.min,
    required this.max, required this.divisions, required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Text(label, style: const TextStyle(
          color: C.textMuted, fontSize: 10,
          fontWeight: FontWeight.w600, letterSpacing: 1.2)),
        const Spacer(),
        Text('${format(values.start)} – ${format(values.end)}',
          style: const TextStyle(
            color: C.textSub, fontSize: 11, fontWeight: FontWeight.w400)),
      ]),
      const SizedBox(height: 6),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: Colors.white,
          inactiveTrackColor: C.fieldBorder,
          thumbColor: Colors.white,
          overlayColor: Colors.white.withOpacity(0.08),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          trackHeight: 1.5,
          rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 5),
        ),
        child: RangeSlider(
          values: values,
          min: min, max: max, divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

class _SearchBtn extends StatefulWidget {
  final String label;
  final bool primary, loading;
  final VoidCallback onTap;
  const _SearchBtn({required this.label, required this.primary,
      required this.loading, required this.onTap});
  @override
  State<_SearchBtn> createState() => _SearchBtnState();
}

class _SearchBtnState extends State<_SearchBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.loading ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 48,
        decoration: BoxDecoration(
          color: widget.primary
              ? (_hovered ? const Color(0xFFEEEEEE) : Colors.white)
              : (_hovered ? const Color(0xFF1E1E1E) : C.field),
          borderRadius: BorderRadius.circular(11),
          border: widget.primary ? null
              : Border.all(color: C.fieldBorder, width: 1)),
        child: Center(child: widget.loading
            ? SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.primary ? Colors.black : C.textSub))
            : Text(widget.label, style: TextStyle(
                color: widget.primary ? Colors.black : C.textSub,
                fontSize: 12, fontWeight: FontWeight.w700,
                letterSpacing: 2))),
      ),
    ),
  );
}

class _ResetBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _ResetBtn({required this.onTap});
  @override
  State<_ResetBtn> createState() => _ResetBtnState();
}

class _ResetBtnState extends State<_ResetBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: Tooltip(
      message: 'Wyczyść filtry',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF1E1E1E) : C.field,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: C.fieldBorder, width: 1)),
          child: Center(child: Icon(Icons.refresh,
            color: _hovered ? C.textSub : C.textMuted, size: 18)),
        ),
      ),
    ),
  );
}