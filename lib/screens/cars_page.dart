import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking_flow.dart';

class C {
  static const bg          = Color(0xFF0A0A0A);
  static const card        = Color(0xFF141414);
  static const cardBorder  = Color(0xFF222222);
  static const field       = Color(0xFF181818);
  static const fieldBorder = Color(0xFF2A2A2A);
  static const fieldActive = Color(0xFF484848);
  static const text        = Color(0xFFFFFFFF);
  static const textSub     = Color(0xFF888888);
  static const textMuted   = Color(0xFF444444);
  static const success     = Color(0xFF55CC88);
  static const divider     = Color(0xFF1A1A1A);
}

enum AlphaSort { none, az, za }
enum PriceSort { none, asc, desc }

// Model reprezentujący GRUPĘ aut tego samego modelu
class CarGroup {
  final int    modelId;
  final String marka;
  final String model;
  final String rodzaj;
  final String opis;
  final int    rok;
  final int    mocKm;
  final double pojemnosc;
  final double spalanie;
  final String naped;
  final String? zdjecie;
  final double minCena;
  final int    dostepne;
  final int    wszystkie;
  final List<Map<String, dynamic>> cennik;
  final double kaucja;
  final List<Map<String, dynamic>> sztuki;
  final DateTime? dostepneOd; // kiedy najbliższy egzemplarz będzie wolny

  const CarGroup({
    required this.modelId, required this.marka, required this.model,
    required this.rodzaj, required this.opis, required this.rok,
    required this.mocKm, required this.pojemnosc, required this.spalanie,
    required this.naped, this.zdjecie,
    required this.minCena, required this.dostepne, required this.wszystkie,
    required this.cennik, required this.kaucja, required this.sztuki,
    this.dostepneOd,
  });
}

// ═══════════════════════════════════════════════════════════════════════
class CarsPage extends StatefulWidget {
  const CarsPage({super.key});
  @override
  State<CarsPage> createState() => _CarsPageState();
}

class _CarsPageState extends State<CarsPage>
    with SingleTickerProviderStateMixin {

  late final AnimationController _sortAnim;
  late final Animation<double>   _sortFade;

  List<CarGroup> _allGroups  = [];
  List<CarGroup> _filtered   = [];
  bool  _loading = true;
  String? _error;

  AlphaSort _alpha = AlphaSort.none;
  PriceSort _price = PriceSort.none;
  final _searchCtrl = TextEditingController();
  bool  _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _sortAnim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 280));
    _sortFade = CurvedAnimation(parent: _sortAnim, curve: Curves.easeInOut);
    _sortAnim.value = 1.0;
    _loadCars();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _sortAnim.dispose();
    _searchCtrl.removeListener(_applyFilters);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCars() async {
    try {
      final res = await Supabase.instance.client
          .from('samochody')
          .select('''
            id, id_modelu, rok_produkcji, numer_rejestracyjny, moc_km, pojemnosc_silnika,
            srednie_spalanie, przebieg, naped, rodzaj, kolor,
            kaucja, status, opis_krotki, url_modelu_3d,
            modele ( nazwa, marki ( nazwa ) ),
            cennik ( min_dni, max_dni, cena_za_dobe ),
            wypozyczenia ( status, data_zakonczenia )
          ''')
          .order('id_modelu');

      final list = (res as List).cast<Map<String, dynamic>>();
      final groups = _buildGroups(list);

      if (mounted) {
        setState(() {
          _allGroups = groups;
          _filtered  = groups;
          _loading   = false;
        });
        _sortAnim.forward();
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  // Grupuje auta po id_modelu
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

      // Cena minimalna z wszystkich egzemplarzy w grupie
      double minCena = double.maxFinite;
      for (final s in sztuki) {
        final c = s['cennik'] as List? ?? [];
        for (final row in c) {
          final p = (row['cena_za_dobe'] as num).toDouble();
          if (p < minCena) minCena = p;
        }
      }

      // Cennik pierwszego egzemplarza (do wyświetlenia)
      final cennik = List<Map>.from(first['cennik'] as List? ?? [])
        ..sort((a, b) => (a['min_dni'] as int).compareTo(b['min_dni'] as int));

      // Dostępne = status 'dostepny' w bazie
      final dostepne = sztuki.where((s) => s['status'] == 'dostepny').length;

      // Oblicz najwcześniejszą datę dostępności (+1 dzień na sprzątanie)
      DateTime? dostepneOd;
      if (dostepne == 0) {
        for (final s in sztuki) {
          // Sprawdź aktywne wypożyczenia tego egzemplarza
          final wyp = s['wypozyczenia'] as List? ?? [];
          for (final w in wyp) {
            if (w['status'] == 'aktywne') {
              try {
                final end = DateTime.parse(w['data_zakonczenia'] as String);
                // +1 dzień na sprzątanie i przegląd
                final freeFrom = end.add(const Duration(days: 2));
                if (dostepneOd == null || freeFrom.isBefore(dostepneOd!)) {
                  dostepneOd = freeFrom;
                }
              } catch (_) {}
            }
          }
          // Jeśli brak danych o wypożyczeniu ale status niedostepny/serwis
          // — nie znamy daty, zostaw null
        }
      }

      groups.add(CarGroup(
        modelId:    entry.key,
        marka:      _safe(first, ['modele', 'marki', 'nazwa']),
        model:      _safe(first, ['modele', 'nazwa']),
        rodzaj:     first['rodzaj'] as String? ?? '',
        opis:       first['opis_krotki'] as String? ?? '',
        rok:        first['rok_produkcji'] as int,
        mocKm:      first['moc_km'] as int,
        pojemnosc:  (first['pojemnosc_silnika'] as num).toDouble(),
        spalanie:   (first['srednie_spalanie'] as num).toDouble(),
        naped:      first['naped'] as String? ?? '',
        zdjecie:    first['url_modelu_3d'] as String?,
        minCena:    minCena == double.maxFinite ? 0 : minCena,
        dostepne:   dostepne,
        wszystkie:  sztuki.length,
        cennik:     cennik.cast<Map<String, dynamic>>(),
        kaucja:     (first['kaucja'] as num).toDouble(),
        sztuki:     sztuki,
        dostepneOd: dostepneOd,
      ));
    }
    return groups;
  }

  String _safe(Map m, List<String> keys) {
    try {
      dynamic v = m;
      for (final k in keys) v = v[k];
      return v as String;
    } catch (_) { return '—'; }
  }

  Future<void> _animatedSort(VoidCallback change) async {
    await _sortAnim.reverse();
    change();
    _applyFilters();
    await _sortAnim.forward();
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    List<CarGroup> res = _allGroups.where((g) {
      if (q.isEmpty) return true;
      return g.marka.toLowerCase().contains(q) ||
             g.model.toLowerCase().contains(q);
    }).toList();

    if (_price != PriceSort.none) {
      res.sort((a, b) => _price == PriceSort.asc
          ? a.minCena.compareTo(b.minCena)
          : b.minCena.compareTo(a.minCena));
    } else if (_alpha != AlphaSort.none) {
      res.sort((a, b) {
        final na = '${a.marka} ${a.model}';
        final nb = '${b.marka} ${b.model}';
        return _alpha == AlphaSort.az ? na.compareTo(nb) : nb.compareTo(na);
      });
    }

    setState(() => _filtered = res);
  }

  void _toggleAlpha() => _animatedSort(() {
    _price = PriceSort.none;
    _alpha = AlphaSort.values[(_alpha.index + 1) % 3];
  });

  void _togglePrice() => _animatedSort(() {
    _alpha = AlphaSort.none;
    _price = PriceSort.values[(_price.index + 1) % 3];
  });

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(
        color: Color(0xFF555555), strokeWidth: 1.5));
    if (_error != null) return Center(child: Text('Błąd: $_error',
        style: const TextStyle(color: C.textSub, fontSize: 13)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterBar(
          searchCtrl:    _searchCtrl,
          searchFocused: _searchFocused,
          onFocusChange: (v) => setState(() => _searchFocused = v),
          alpha:         _alpha,
          price:         _price,
          onAlphaTap:    _toggleAlpha,
          onPriceTap:    _togglePrice,
          resultCount:   _filtered.length,
        ),
        Expanded(
          child: FadeTransition(
            opacity: _sortFade,
            child: _filtered.isEmpty
                ? const Center(child: Text('Brak wyników',
                    style: TextStyle(color: C.textMuted, fontSize: 14)))
                : _CarsGrid(groups: _filtered, onRefresh: _loadCars),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PASEK FILTRÓW
// ═══════════════════════════════════════════════════════════════════════
class _FilterBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final bool searchFocused;
  final ValueChanged<bool> onFocusChange;
  final AlphaSort alpha;
  final PriceSort price;
  final VoidCallback onAlphaTap, onPriceTap;
  final int resultCount;

  const _FilterBar({
    required this.searchCtrl, required this.searchFocused,
    required this.onFocusChange, required this.alpha, required this.price,
    required this.onAlphaTap, required this.onPriceTap, required this.resultCount,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final pad = isMobile ? 16.0 : 28.0;
    return Container(
    padding: EdgeInsets.fromLTRB(pad, isMobile ? 16 : 24, pad, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Wszystkie auta', style: TextStyle(
          color: C.text, fontSize: isMobile ? 18 : 22,
          fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: C.field,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: C.fieldBorder, width: 1)),
          child: Text('$resultCount modeli', style: const TextStyle(
            color: C.textSub, fontSize: 11))),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(flex: 3,
          child: _SearchField(controller: searchCtrl,
            focused: searchFocused, onFocusChange: onFocusChange)),
        const SizedBox(width: 8),
        _FilterBtn(onTap: onAlphaTap, active: alpha != AlphaSort.none,
          tooltip: alpha == AlphaSort.none ? 'Sortuj A→Z'
              : (alpha == AlphaSort.az ? 'A→Z' : 'Z→A'),
          child: _AlphaIcon(state: alpha)),
        const SizedBox(width: 6),
        _FilterBtn(onTap: onPriceTap, active: price != PriceSort.none,
          tooltip: price == PriceSort.none ? 'Sortuj cenowo'
              : (price == PriceSort.asc ? 'Najtańsze' : 'Najdroższe'),
          child: _PriceIcon(state: price)),
      ]),
      const SizedBox(height: 14),
      Container(height: 1, color: C.divider),
    ]),
  );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool focused;
  final ValueChanged<bool> onFocusChange;
  const _SearchField({required this.controller, required this.focused,
      required this.onFocusChange});
  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: onFocusChange,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 42,
      decoration: BoxDecoration(
        color: focused ? C.field : const Color(0x0CFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: focused ? C.fieldActive : C.fieldBorder, width: 1)),
      child: Row(children: [
        const SizedBox(width: 12),
        Icon(Icons.search, size: 16,
            color: focused ? C.textSub : C.textMuted),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: controller,
          style: const TextStyle(color: C.text, fontSize: 13,
              fontWeight: FontWeight.w300),
          decoration: const InputDecoration(
            hintText: 'Szukaj marki lub modelu...',
            hintStyle: TextStyle(color: C.textMuted, fontSize: 13,
                fontWeight: FontWeight.w300),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12)),
          cursorColor: C.textSub, cursorWidth: 1)),
        if (controller.text.isNotEmpty)
          GestureDetector(
            onTap: controller.clear,
            child: const Padding(padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.close, size: 14, color: C.textMuted))),
      ]),
    ),
  );
}

class _FilterBtn extends StatefulWidget {
  final VoidCallback onTap;
  final bool active;
  final Widget child;
  final String tooltip;
  const _FilterBtn({required this.onTap, required this.active,
      required this.child, required this.tooltip});
  @override
  State<_FilterBtn> createState() => _FilterBtnState();
}
class _FilterBtnState extends State<_FilterBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tooltip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: widget.active
                ? Colors.white.withOpacity(0.08)
                : (_hovered ? C.field : const Color(0x0CFFFFFF)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.active
                  ? Colors.white.withOpacity(0.22) : C.fieldBorder,
              width: 1)),
          child: Center(child: widget.child)),
      ),
    ),
  );
}

class _AlphaIcon extends StatelessWidget {
  final AlphaSort state;
  const _AlphaIcon({required this.state});
  @override
  Widget build(BuildContext context) {
    switch (state) {
      case AlphaSort.none: return const Icon(Icons.sort_by_alpha,
          size: 17, color: C.textMuted);
      case AlphaSort.az:   return const Text('A', style: TextStyle(
          color: C.text, fontSize: 16, fontWeight: FontWeight.w700));
      case AlphaSort.za:   return const Text('Z', style: TextStyle(
          color: C.text, fontSize: 16, fontWeight: FontWeight.w700));
    }
  }
}

class _PriceIcon extends StatelessWidget {
  final PriceSort state;
  const _PriceIcon({required this.state});
  @override
  Widget build(BuildContext context) {
    switch (state) {
      case PriceSort.none: return const Icon(Icons.attach_money,
          size: 17, color: C.textMuted);
      case PriceSort.asc:  return const Icon(Icons.arrow_downward,
          size: 16, color: C.text);
      case PriceSort.desc: return const Icon(Icons.arrow_upward,
          size: 16, color: C.text);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SIATKA
// ═══════════════════════════════════════════════════════════════════════
class _CarsGrid extends StatelessWidget {
  final List<CarGroup> groups;
  final VoidCallback? onRefresh;
  const _CarsGrid({required this.groups, this.onRefresh});
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final pad = isMobile ? 12.0 : 28.0;
    final cols = isMobile ? 2
        : (MediaQuery.of(context).size.width > 1200 ? 4 : 3);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(pad, 14, pad, 32),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: isMobile ? 8 : 12,
        mainAxisSpacing: isMobile ? 8 : 12,
        childAspectRatio: isMobile ? 0.56 : 0.70),
      itemCount: groups.length,
      itemBuilder: (ctx, i) => _CarTile(
          group: groups[i], onRefresh: onRefresh),
    );
  }
}

// Globalna mapa model → asset
String? assetForModel(String model) {
  const map = {
    '911':      'assets/images/911.png',
    'A4':       'assets/images/a4.png',
    'C Klasa':  'assets/images/cklasa.png',
    'Clio':     'assets/images/clio.png',
    'Corolla':  'assets/images/corolla.png',
    'CX-5':     'assets/images/cx-5.png',
    'Focus':    'assets/images/focus.png',
    'Golf':     'assets/images/golf.png',
    'Huracan':  'assets/images/huracan.png',
    'Kodiaq':   'assets/images/kodiaq.png',
    'Leon':     'assets/images/leon.png',
    'M3':       'assets/images/m3.png',
    'Macan':    'assets/images/macan.png',
    'Mustang':  'assets/images/mustang.png',
    'MX-5':     'assets/images/mx-5.png',
    'Octavia':  'assets/images/octavia.png',
    'Passat':   'assets/images/passat.png',
    'Polo':     'assets/images/polo.png',
    'Q5':       'assets/images/q5.png',
    'RAV4':     'assets/images/rav4.png',
    'Roma':     'assets/images/roma.png',
    'Seria 3':  'assets/images/seria3.png',
    'Seria 5':  'assets/images/seria5.png',
    'Sportage': 'assets/images/sportage.png',
    'Stinger':  'assets/images/stinger.png',
    'Superb':   'assets/images/superb.png',
    'Tiguan':   'assets/images/tiguan.png',
    'Tucson':   'assets/images/tucson.png',
    'X5':       'assets/images/x5.png',
    'Yaris':    'assets/images/yaris.png',
  };
  return map[model];
}

// ═══════════════════════════════════════════════════════════════════════
// KAFELEK — jeden model
// ═══════════════════════════════════════════════════════════════════════
class _CarTile extends StatefulWidget {
  final CarGroup group;
  final VoidCallback? onRefresh;
  const _CarTile({required this.group, this.onRefresh});
  @override
  State<_CarTile> createState() => _CarTileState();
}

class _CarTileState extends State<_CarTile> {
  bool _hovered = false;

  CarGroup get g => widget.group;
  bool get _anyAvailable => g.dostepne > 0;

  @override
  Widget build(BuildContext context) {
    final opisShort = g.opis.length > 70
        ? '${g.opis.substring(0, 67)}...' : g.opis;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _showDetail(context),
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
            opacity: _anyAvailable ? 1.0 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zdjęcie
                Expanded(flex: 8,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13)),
                    child: _buildImage(),
                  ),
                ),
                // Dane
                Expanded(flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tytuł
                        Text('${g.marka} ${g.model}',
                          style: const TextStyle(color: C.text,
                            fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 1),
                        Text('${g.rok} · ${g.mocKm} KM',
                          style: const TextStyle(color: C.textMuted,
                            fontSize: 10, fontWeight: FontWeight.w300)),
                        if (opisShort.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(opisShort,
                            style: const TextStyle(color: C.textSub,
                              fontSize: 9, fontWeight: FontWeight.w300,
                              height: 1.3),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                        const Spacer(),
                        Row(children: [
                          Expanded(
                            child: Text(
                              g.minCena > 0
                                  ? 'od ${g.minCena.toInt()} zł/dobę'
                                  : 'Wycena',
                              style: const TextStyle(color: C.text,
                                fontSize: 10, fontWeight: FontWeight.w500),
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

  Widget _buildImage() {
    final url = g.zdjecie;
    // Najpierw próbuj lokalnego assetu
    final asset = assetForModel(g.model);
    if (asset != null) {
      return Container(
        width: double.infinity,
        color: const Color(0xFF0F0F0F),
        child: Stack(children: [
          // Zdjęcie wypełnia całą przestrzeń
          Positioned.fill(
            child: Transform.scale(
              scale: 1.6,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
            ),
          ),
          // Badge rodzaju
          Positioned(top: 10, left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: Colors.white.withOpacity(0.06), width: 1)),
              child: Text(g.rodzaj, style: const TextStyle(
                color: C.textSub, fontSize: 9,
                fontWeight: FontWeight.w400, letterSpacing: 0.4)))),
        ]),
      );
    }
    if (url != null && url.isNotEmpty) {
      return Image.network(url, fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder());
    }
    return _placeholder();
  }

  String? _assetForModel(String model) => assetForModel(model);

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F0F0F),
      child: Stack(children: [
        Positioned.fill(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _color(g.rodzaj).withOpacity(0.05),
                Colors.transparent])))),
        Center(child: Icon(_icon(g.rodzaj),
            size: 46, color: const Color(0xFF252525))),
        Positioned(top: 10, left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: Colors.white.withOpacity(0.06), width: 1)),
            child: Text(g.rodzaj, style: const TextStyle(
              color: C.textSub, fontSize: 9, fontWeight: FontWeight.w400,
              letterSpacing: 0.4)))),
      ]),
    );
  }

  IconData _icon(String r) {
    switch (r) {
      case 'van':    return Icons.airport_shuttle_outlined;
      case 'cabrio': return Icons.wb_sunny_outlined;
      case 'coupe':  return Icons.directions_car;
      default:       return Icons.directions_car_outlined;
    }
  }

  Color _color(String r) {
    switch (r) {
      case 'SUV':    return const Color(0xFF3366AA);
      case 'coupe':  return const Color(0xFFAA3333);
      case 'cabrio': return const Color(0xFFAA8833);
      default:       return const Color(0xFF444444);
    }
  }

  void _showDetail(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => CarDetail(group: g, onRefresh: widget.onRefresh),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: anim, curve: Curves.easeOutCubic)),
          child: child)),
    );
  }
}

// Badge dostępności
class AvailBadge extends StatelessWidget {
  final int dostepne, wszystkie;
  final DateTime? dostepneOd;
  const AvailBadge({required this.dostepne, required this.wszystkie,
      this.dostepneOd});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    if (dostepne > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: C.success.withOpacity(0.12),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: C.success.withOpacity(0.3), width: 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 5, height: 5,
            decoration: const BoxDecoration(
              color: C.success, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            dostepne == 1 && wszystkie > 1
                ? 'Ostatnia sztuka!'
                : 'Dostępne',
            style: const TextStyle(color: C.success, fontSize: 9,
                fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ]),
      );
    }

    // Niedostępne — pokaż datę jeśli znana
    final color = const Color(0xFF888888);
    final label = dostepneOd != null
        ? 'od ${_fmt(dostepneOd!)}'
        : 'Niedostępny';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.25), width: 1)),
      child: Text(label, style: TextStyle(
        color: color, fontSize: 9,
        fontWeight: FontWeight.w600, letterSpacing: 0.3)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// MODAL SZCZEGÓŁÓW
// ═══════════════════════════════════════════════════════════════════════
class CarDetail extends StatefulWidget {
  final CarGroup group;
  final VoidCallback? onRefresh;
  const CarDetail({required this.group, this.onRefresh});
  @override
  State<CarDetail> createState() => CarDetailState();
}

class CarDetailState extends State<CarDetail> {
  int? _selectedSztuka;
  bool _showBooking = false;

  CarGroup get g => widget.group;

  List<Map<String, dynamic>> get _dostepneSztuki =>
      g.sztuki.where((s) => s['status'] == 'dostepny').toList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: C.cardBorder, width: 1)),
              child: Column(children: [
                // Nagłówek
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 14, 0),
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${g.marka} ${g.model}',
                          style: const TextStyle(color: C.text,
                            fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${g.rok} · ${g.rodzaj} · ${g.naped}',
                          style: const TextStyle(color: C.textSub,
                            fontSize: 12, fontWeight: FontWeight.w300)),
                      ])),
                    // Licznik sztuk
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: g.dostepne > 0
                            ? C.success.withOpacity(0.1)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: g.dostepne > 0
                              ? C.success.withOpacity(0.3)
                              : C.fieldBorder,
                          width: 1)),
                      child: Column(children: [
                        Text(
                          g.dostepne > 0
                              ? '${g.dostepne}'
                              : (g.dostepneOd != null
                                  ? '${g.dostepneOd!.day.toString().padLeft(2,'0')}.${g.dostepneOd!.month.toString().padLeft(2,'0')}'
                                  : '0'),
                          style: TextStyle(
                            color: g.dostepne > 0 ? C.success : C.textMuted,
                            fontSize: g.dostepne > 0 ? 18 : 14,
                            fontWeight: FontWeight.w700)),
                        Text(
                          g.dostepne > 0
                              ? 'dostępne'
                              : (g.dostepneOd != null
                                  ? 'wolne od' : 'niedostępne'),
                          style: const TextStyle(
                            color: C.textMuted, fontSize: 9,
                            fontWeight: FontWeight.w300)),
                      ])),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close,
                          color: C.textMuted, size: 17)),
                  ]),
                ),

                const Divider(color: C.divider, height: 22),

                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: _showBooking
                      ? BookingFlow(
                          group: g,
                          selectedSztuka: _selectedSztuka,
                          onCancel: () => setState(() => _showBooking = false),
                          onSuccess: () {
                            widget.onRefresh?.call();
                          },
                        )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Zdjęcie / placeholder
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D0D0D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.cardBorder, width: 1)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            color: const Color(0xFF0D0D0D),
                            child: assetForModel(g.model) != null
                                ? Stack(children: [
                                    Positioned.fill(child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          center: Alignment.center,
                                          radius: 0.9,
                                          colors: [
                                            const Color(0xFF1A1A1A),
                                            const Color(0xFF0D0D0D),
                                          ])))),
                                    Center(child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Image.asset(
                                        assetForModel(g.model)!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.directions_car_outlined,
                                                size: 56, color: Color(0xFF252525))))),
                                  ])
                                : g.zdjecie != null
                                    ? Image.network(g.zdjecie!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.directions_car_outlined,
                                                size: 56, color: Color(0xFF252525)))
                                    : const Center(child: Icon(
                                        Icons.directions_car_outlined,
                                        size: 56, color: Color(0xFF252525))),
                          ),
                        )),

                      const SizedBox(height: 18),

                      // Opis
                      if (g.opis.isNotEmpty) ...[
                        Text(g.opis, style: const TextStyle(
                          color: C.textSub, fontSize: 13,
                          fontWeight: FontWeight.w300, height: 1.6)),
                        const SizedBox(height: 16),
                      ],

                      // Parametry
                      const _Label('Parametry techniczne'),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _Chip('${g.mocKm} KM'),
                        _Chip('${g.pojemnosc} l'),
                        _Chip('${g.spalanie} l/100km'),
                        _Chip(g.naped),
                      ]),
                      const SizedBox(height: 18),

                      // Dostępne egzemplarze
                      if (_dostepneSztuki.isNotEmpty) ...[
                        Row(children: [
                          const _Label('Dostępne egzemplarze'),
                          const SizedBox(width: 8),
                          Text('(wybierz)',
                            style: const TextStyle(color: C.textMuted,
                                fontSize: 11, fontWeight: FontWeight.w300)),
                        ]),
                        const SizedBox(height: 10),
                        ..._dostepneSztuki.map((s) {
                          final sid = s['id'] as int;
                          final selected = _selectedSztuka == sid;
                          return GestureDetector(
                            onTap: () => setState(() =>
                                _selectedSztuka = selected ? null : sid),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white.withOpacity(0.06)
                                    : C.field,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? Colors.white.withOpacity(0.2)
                                      : C.fieldBorder,
                                  width: 1)),
                              child: Row(children: [
                                // Kolor
                                Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(
                                    color: _colorFromName(
                                        s['kolor'] as String? ?? ''),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 1))),
                                const SizedBox(width: 10),
                                Expanded(child: Text(
                                  '${s['kolor']} · ${s['rok_produkcji']} · '
                                  '${s['numer_rejestracyjny']}',
                                  style: const TextStyle(color: C.text,
                                    fontSize: 12, fontWeight: FontWeight.w300))),
                                if (selected)
                                  const Icon(Icons.check_circle,
                                      color: C.success, size: 16),
                              ]),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],

                      // Cennik
                      if (g.cennik.isNotEmpty) ...[
                        const _Label('Cennik'),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: C.cardBorder, width: 1)),
                          child: Column(children: g.cennik.map((c) {
                            final isLast = c == g.cennik.last;
                            final min = c['min_dni'] as int;
                            final max = c['max_dni'] as int;
                            final p   = (c['cena_za_dobe'] as num).toInt();
                            final lbl = min == max
                                ? '$min dób' : '$min–$max dób';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                border: !isLast ? const Border(bottom:
                                    BorderSide(color: C.divider, width: 1))
                                    : null),
                              child: Row(children: [
                                Expanded(child: Text(lbl,
                                  style: const TextStyle(color: C.textSub,
                                    fontSize: 12, fontWeight: FontWeight.w300))),
                                Text('$p zł / dobę',
                                  style: const TextStyle(color: C.text,
                                    fontSize: 12, fontWeight: FontWeight.w500)),
                              ]));
                          }).toList()),
                        ),
                        const SizedBox(height: 12),
                      ],

                      Row(children: [
                        const Text('Kaucja: ', style: TextStyle(
                          color: C.textSub, fontSize: 12,
                          fontWeight: FontWeight.w300)),
                        Text('${g.kaucja.toInt()} zł',
                          style: const TextStyle(color: C.text,
                            fontSize: 12, fontWeight: FontWeight.w500)),
                      ]),
                      const SizedBox(height: 22),
                    ],
                  ),
                )),

                // Przycisk — tylko gdy nie w trybie rezerwacji
                if (!_showBooking)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: SizedBox(
                      width: double.infinity,
                      child: _ReserveButton(
                        dostepne: g.dostepne,
                        selectedSztuka: _selectedSztuka,
                        onReserve: () => setState(() => _showBooking = true),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Color _colorFromName(String n) {
    switch (n.toLowerCase()) {
      case 'czarny':       return const Color(0xFF1A1A1A);
      case 'biały':        return const Color(0xFFF0F0F0);
      case 'szary':        return const Color(0xFF808080);
      case 'czerwony':     return const Color(0xFFCC3333);
      case 'niebieski':    return const Color(0xFF3366CC);
      case 'granatowy':    return const Color(0xFF1A2A5E);
      case 'żółty':        return const Color(0xFFCCAA00);
      case 'pomarańczowy': return const Color(0xFFCC6600);
      default:             return const Color(0xFF444444);
    }
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
    color: C.text, fontSize: 12, fontWeight: FontWeight.w600,
    letterSpacing: 0.3));
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: C.field,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: C.fieldBorder, width: 1)),
    child: Text(label, style: const TextStyle(
      color: C.textSub, fontSize: 11, fontWeight: FontWeight.w300)));
}

// ═══════════════════════════════════════════════════════════════════════
// PRZYCISK REZERWACJI — reaguje na stan logowania
// ═══════════════════════════════════════════════════════════════════════
class _ReserveButton extends StatefulWidget {
  final int dostepne;
  final int? selectedSztuka;
  final VoidCallback onReserve;
  const _ReserveButton({required this.dostepne, required this.selectedSztuka,
      required this.onReserve});
  @override
  State<_ReserveButton> createState() => _ReserveButtonState();
}

class _ReserveButtonState extends State<_ReserveButton> {
  bool _hovered = false;

  bool get _loggedIn =>
      Supabase.instance.client.auth.currentUser != null;

  @override
  Widget build(BuildContext context) {
    final available = widget.dostepne > 0;

    // Niedostępne auto
    if (!available) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(10)),
        child: const Center(child: Text('NIEDOSTĘPNY',
          style: TextStyle(color: C.textMuted, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 1.8))),
      );
    }

    // Dostępne ale niezalogowany
    if (!_loggedIn) {
      return MouseRegion(
        cursor: SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF2A2A2A) : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _hovered
                    ? const Color(0xFF444444) : const Color(0xFF2A2A2A),
                width: 1)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline,
                color: _hovered ? C.textSub : C.textMuted, size: 14),
            const SizedBox(width: 8),
            Text(
              _hovered ? 'ZALOGUJ SIĘ ABY ZAREZERWOWAĆ' : 'ZAREZERWUJ',
              style: TextStyle(
                color: _hovered ? C.textSub : C.textMuted,
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1.4)),
          ]),
        ),
      );
    }

    // Dostępne i zalogowany
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onReserve,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 48,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFFEEEEEE) : Colors.white,
            borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(
            widget.selectedSztuka != null
                ? 'ZAREZERWUJ WYBRANY EGZEMPLARZ'
                : 'ZAREZERWUJ',
            style: const TextStyle(
              color: Colors.black, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 1.8))),
        ),
      ),
    );
  }
}