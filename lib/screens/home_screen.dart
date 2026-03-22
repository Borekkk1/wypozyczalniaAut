import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class AppColors {
  static const bg           = Color(0xFF0A0A0A);
  static const sidebar      = Color(0xFF111111);
  static const sidebarBorder= Color(0xFF1E1E1E);
  static const card         = Color(0xFF141414);
  static const cardBorder   = Color(0xFF222222);
  static const field        = Color(0xFF181818);
  static const fieldBorder  = Color(0xFF2A2A2A);
  static const fieldActive  = Color(0xFF444444);
  static const textPrimary  = Color(0xFFFFFFFF);
  static const textSecondary= Color(0xFF888888);
  static const textMuted    = Color(0xFF444444);
  static const accent       = Color(0xFFFFFFFF);
  static const iconActive   = Color(0xFFFFFFFF);
  static const iconInactive = Color(0xFF555555);
  static const divider      = Color(0xFF1E1E1E);
  static const btnPrimary   = Color(0xFFFFFFFF);
  static const btnText      = Color(0xFF0A0A0A);
}

// ═══════════════════════════════════════════════════════════════════════
// EKRAN GŁÓWNY
// ═══════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activePage = 0; // 0=szukaj, 1=lista, 2=regulamin, 3=cennik

  // Stan zalogowania
  bool get _isLoggedIn =>
      Supabase.instance.client.auth.currentUser != null;

  String get _username {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.email?.split('@').first ?? '';
  }

  void _openLogin() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, __, ___) => const _LoginOverlay(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim, child: child),
      ),
    ).then((_) => setState(() {}));
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          // ── SIDEBAR ─────────────────────────────────────────────────
          _Sidebar(
            activePage: _activePage,
            isLoggedIn: _isLoggedIn,
            username: _username,
            onPageChanged: (i) => setState(() => _activePage = i),
            onLoginTap: _isLoggedIn ? _logout : _openLogin,
          ),

          // ── MAIN CONTENT ─────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildPage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_activePage) {
      case 0: return const _SearchPage(key: ValueKey(0));
      case 1: return const _CarsPage(key: ValueKey(1));
      case 2: return const _TermsPage(key: ValueKey(2));
      case 3: return const _PricingPage(key: ValueKey(3));
      default: return const _SearchPage(key: ValueKey(0));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SIDEBAR
// ═══════════════════════════════════════════════════════════════════════
class _Sidebar extends StatelessWidget {
  final int activePage;
  final bool isLoggedIn;
  final String username;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onLoginTap;

  const _Sidebar({
    required this.activePage,
    required this.isLoggedIn,
    required this.username,
    required this.onPageChanged,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(
          right: BorderSide(color: AppColors.sidebarBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // ── UŻYTKOWNIK (góra, większy) ───────────────────────────────
          _UserButton(
            isLoggedIn: isLoggedIn,
            username: username,
            onTap: onLoginTap,
          ),

          Container(height: 1, color: AppColors.divider, margin:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),

          // ── NAWIGACJA ────────────────────────────────────────────────
          _NavItem(
            icon: Icons.search_rounded,
            label: 'Szukaj',
            active: activePage == 0,
            onTap: () => onPageChanged(0),
          ),
          _NavItem(
            icon: Icons.directions_car_outlined,
            label: 'Wszystkie auta',
            active: activePage == 1,
            onTap: () => onPageChanged(1),
          ),
          _NavItem(
            icon: Icons.description_outlined,
            label: 'Regulamin',
            active: activePage == 2,
            onTap: () => onPageChanged(2),
          ),
          _NavItem(
            icon: Icons.local_offer_outlined,
            label: 'Cennik & Zniżki',
            active: activePage == 3,
            onTap: () => onPageChanged(3),
          ),

          const Spacer(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Przycisk użytkownika (większy, na górze)
class _UserButton extends StatefulWidget {
  final bool isLoggedIn;
  final String username;
  final VoidCallback onTap;
  const _UserButton({required this.isLoggedIn, required this.username,
      required this.onTap});
  @override
  State<_UserButton> createState() => _UserButtonState();
}

class _UserButtonState extends State<_UserButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter:  (_) => setState(() => _hovered = true),
      onExit:   (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.isLoggedIn
              ? 'Wyloguj (${widget.username})' : 'Zaloguj się',
          preferBelow: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44, height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.card
                  : (widget.isLoggedIn
                      ? AppColors.accent.withOpacity(0.12)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isLoggedIn
                    ? AppColors.accent.withOpacity(0.4)
                    : AppColors.sidebarBorder,
                width: 1,
              ),
            ),
            child: Center(
              child: widget.isLoggedIn
                  ? Text(
                      widget.username.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16, fontWeight: FontWeight.w600,
                      ))
                  : const Icon(Icons.person_outline,
                      color: AppColors.iconInactive, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// Nav item z tooltipem
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label,
      required this.active, required this.onTap});
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter:  (_) => setState(() => _hovered = true),
      onExit:   (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.label,
          preferBelow: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44, height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: widget.active
                  ? AppColors.card
                  : (_hovered ? AppColors.sidebarBorder.withOpacity(0.3) : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: widget.active
                  ? Border.all(color: AppColors.cardBorder, width: 1)
                  : null,
            ),
            child: Center(
              child: Icon(
                widget.icon,
                color: widget.active
                    ? AppColors.iconActive : AppColors.iconInactive,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// STRONA WYSZUKIWANIA
// ═══════════════════════════════════════════════════════════════════════
class _SearchPage extends StatefulWidget {
  const _SearchPage({super.key});
  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage>
    with SingleTickerProviderStateMixin {

  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // Filtry
  String? _selectedMarka;
  String? _selectedModel;
  RangeValues _rokRange    = const RangeValues(2010, 2024);
  RangeValues _mocRange    = const RangeValues(70, 700);
  RangeValues _spalRange   = const RangeValues(4, 18);
  String? _selectedNaped;
  String? _selectedRodzaj;
  String? _selectedKolor;
  RangeValues _pojRange    = const RangeValues(1.0, 6.0);

  // Dane do dropdownów (uproszczone — do pełnej integracji z Supabase)
  final _marki = ['BMW', 'Audi', 'Mercedes', 'Toyota', 'Ford', 'Volkswagen',
    'Skoda', 'Seat', 'Mazda', 'Hyundai', 'Kia', 'Renault', 'Peugeot',
    'Honda', 'Nissan', 'Porsche', 'Lamborghini', 'Ferrari', 'Maserati', 'Alfa Romeo'];

  final Map<String, List<String>> _modelyMap = {
    'BMW': ['Seria 3', 'Seria 5', 'X3', 'X5', 'M3', 'M5', 'X6'],
    'Audi': ['A3', 'A4', 'A6', 'Q3', 'Q5', 'Q7', 'TT', 'RS6'],
    'Mercedes': ['C Klasa', 'E Klasa', 'S Klasa', 'GLE', 'GLC', 'A Klasa', 'AMG GT'],
    'Toyota': ['Corolla', 'Camry', 'RAV4', 'Land Cruiser', 'Yaris', 'C-HR'],
    'Ford': ['Focus', 'Mondeo', 'Mustang', 'Explorer', 'Puma', 'Kuga'],
    'Volkswagen': ['Golf', 'Passat', 'Tiguan', 'Polo', 'Touareg', 'Arteon'],
    'Skoda': ['Octavia', 'Superb', 'Karoq', 'Kodiaq', 'Fabia'],
    'Seat': ['Leon', 'Ibiza', 'Ateca', 'Tarraco'],
    'Mazda': ['Mazda 3', 'Mazda 6', 'CX-5', 'CX-30', 'MX-5'],
    'Hyundai': ['i30', 'Tucson', 'Santa Fe', 'Kona', 'i20'],
    'Kia': ['Ceed', 'Sportage', 'Sorento', 'Stinger', 'Niro'],
    'Renault': ['Clio', 'Megane', 'Kadjar', 'Koleos', 'Arkana'],
    'Peugeot': ['308', '508', '3008', '5008', '208'],
    'Honda': ['Civic', 'CR-V', 'HR-V', 'Jazz'],
    'Nissan': ['Qashqai', 'X-Trail', 'Juke', '370Z'],
    'Porsche': ['911', 'Cayenne', 'Macan', 'Panamera'],
    'Lamborghini': ['Huracan', 'Urus'],
    'Ferrari': ['Roma', 'F8'],
    'Maserati': ['Ghibli', 'Levante'],
    'Alfa Romeo': ['Giulia', 'Stelvio', 'Tonale'],
  };

  final _napedy  = ['FWD', 'RWD', '4x4', 'AWD'];
  final _rodzaje = ['sedan', 'SUV', 'van', 'coupe', 'cabrio', 'kombi', 'hatchback'];
  final _kolory  = ['biały', 'czarny', 'szary', 'czerwony', 'niebieski',
    'granatowy', 'pomarańczowy', 'żółty'];

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── NAGŁÓWEK ──────────────────────────────────────────────
              const Text('Wypożyczalnia Aut', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 28,
                fontWeight: FontWeight.w700, letterSpacing: -0.5,
              )),
              const SizedBox(height: 6),
              const Text('Znajdź idealne auto dla siebie',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 15, fontWeight: FontWeight.w300)),
              const SizedBox(height: 40),

              // ── KARTA FILTRÓW ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder, width: 1),
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Szukaj auta', style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 16,
                      fontWeight: FontWeight.w600, letterSpacing: 0.2,
                    )),
                    const SizedBox(height: 24),

                    // Rząd 1: Marka + Model
                    _buildRow([
                      _buildDropdown('Marka', _marki, _selectedMarka,
                        (v) => setState(() {
                          _selectedMarka = v;
                          _selectedModel = null;
                        })),
                      _buildDropdown(
                        'Model',
                        _selectedMarka != null
                            ? (_modelyMap[_selectedMarka] ?? [])
                            : [],
                        _selectedModel,
                        (v) => setState(() => _selectedModel = v),
                        disabled: _selectedMarka == null,
                        hint: _selectedMarka == null
                            ? 'Najpierw wybierz markę' : 'Model',
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // Rząd 2: Rocznik + Moc
                    _buildRow([
                      _buildRangeField('Rocznik', _rokRange,
                        min: 2000, max: 2024, divisions: 24,
                        format: (v) => v.toInt().toString(),
                        onChanged: (v) => setState(() => _rokRange = v)),
                      _buildRangeField('Moc (KM)', _mocRange,
                        min: 70, max: 800, divisions: 73,
                        format: (v) => '${v.toInt()} KM',
                        onChanged: (v) => setState(() => _mocRange = v)),
                    ]),
                    const SizedBox(height: 20),

                    // Rząd 3: Spalanie + Pojemność
                    _buildRow([
                      _buildRangeField('Śr. spalanie (l/100km)', _spalRange,
                        min: 4, max: 20, divisions: 16,
                        format: (v) => '${v.toStringAsFixed(1)} l',
                        onChanged: (v) => setState(() => _spalRange = v)),
                      _buildRangeField('Pojemność silnika (l)', _pojRange,
                        min: 0.8, max: 6.5, divisions: 57,
                        format: (v) => '${v.toStringAsFixed(1)} l',
                        onChanged: (v) => setState(() => _pojRange = v)),
                    ]),
                    const SizedBox(height: 20),

                    // Rząd 4: Rodzaj + Napęd + Kolor
                    _buildRow([
                      _buildDropdown('Rodzaj', _rodzaje, _selectedRodzaj,
                        (v) => setState(() => _selectedRodzaj = v)),
                      _buildDropdown('Napęd', _napedy, _selectedNaped,
                        (v) => setState(() => _selectedNaped = v)),
                      _buildDropdown('Kolor', _kolory, _selectedKolor,
                        (v) => setState(() => _selectedKolor = v)),
                    ]),
                    const SizedBox(height: 28),

                    // Przyciski
                    Row(children: [
                      Expanded(
                        child: _SearchButton(
                          label: 'SZUKAJ',
                          primary: true,
                          onTap: () {}, // TODO: przejście do listy
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SearchButton(
                          label: 'POKAŻ WSZYSTKIE',
                          primary: false,
                          onTap: () {}, // TODO: pokaż wszystkie
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Rząd 2 lub 3 kolumn
  Widget _buildRow(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((c) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(
            right: c != children.last ? 16 : 0),
          child: c,
        ),
      )).toList(),
    );
  }

  // Dropdown z etykietą
  Widget _buildDropdown(String label, List<String> items, String? value,
      ValueChanged<String?> onChanged,
      {bool disabled = false, String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
        color: AppColors.textSecondary, fontSize: 11,
        fontWeight: FontWeight.w500, letterSpacing: 0.8,
      )),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: disabled ? AppColors.field.withOpacity(0.5) : AppColors.field,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.fieldBorder, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(hint ?? 'Wybierz...',
              style: TextStyle(
                color: disabled
                    ? AppColors.textMuted.withOpacity(0.5)
                    : AppColors.textMuted,
                fontSize: 13)),
            isExpanded: true,
            dropdownColor: const Color(0xFF1A1A1A),
            icon: Icon(Icons.keyboard_arrow_down,
              color: disabled ? AppColors.textMuted.withOpacity(0.3)
                  : AppColors.textMuted, size: 18),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            items: disabled ? [] : [
              // Opcja "Wszystkie" (null)
              DropdownMenuItem<String>(
                value: null,
                child: Text('Wszystkie',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
              ...items.map((i) => DropdownMenuItem(value: i,
                  child: Text(i))),
            ],
            onChanged: disabled ? null : onChanged,
          ),
        ),
      ),
    ]);
  }

  // Zakres z suwakiem
  Widget _buildRangeField(String label, RangeValues values,
      {required double min, required double max, required int divisions,
       required String Function(double) format,
       required ValueChanged<RangeValues> onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 11,
          fontWeight: FontWeight.w500, letterSpacing: 0.8,
        )),
        const Spacer(),
        Text('${format(values.start)} – ${format(values.end)}',
          style: const TextStyle(color: AppColors.textPrimary,
              fontSize: 11, fontWeight: FontWeight.w400)),
      ]),
      const SizedBox(height: 6),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: AppColors.textPrimary,
          inactiveTrackColor: AppColors.fieldBorder,
          thumbColor: AppColors.textPrimary,
          overlayColor: AppColors.textPrimary.withOpacity(0.1),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          trackHeight: 2,
        ),
        child: RangeSlider(
          values: values,
          min: min, max: max, divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// STRONA LISTY AUT (placeholder)
// ═══════════════════════════════════════════════════════════════════════
class _CarsPage extends StatelessWidget {
  const _CarsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Lista aut — wkrótce',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 16)));
  }
}

// ═══════════════════════════════════════════════════════════════════════
// STRONA REGULAMINU (placeholder)
// ═══════════════════════════════════════════════════════════════════════
class _TermsPage extends StatelessWidget {
  const _TermsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Regulamin — wkrótce',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 16)));
  }
}

// ═══════════════════════════════════════════════════════════════════════
// STRONA CENNIKA (placeholder)
// ═══════════════════════════════════════════════════════════════════════
class _PricingPage extends StatelessWidget {
  const _PricingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Cennik & Zniżki — wkrótce',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 16)));
  }
}

// ═══════════════════════════════════════════════════════════════════════
// OVERLAY LOGOWANIA
// ═══════════════════════════════════════════════════════════════════════
class _LoginOverlay extends StatelessWidget {
  const _LoginOverlay();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () {}, // blokuje zamknięcie przy tapie w kartę
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              // Reuse LoginScreen ale tylko jako widget
              child: const _InlineLogin(),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineLogin extends StatelessWidget {
  const _InlineLogin();
  @override
  Widget build(BuildContext context) {
    // Tu możesz użyć LoginScreen z odpowiednią nawigacją
    // Na razie prosty placeholder — pełne logowanie przez LoginScreen
    return Container(
      margin: const EdgeInsets.all(28),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Zaloguj się', style: TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Aby wypożyczyć auto, zaloguj się na swoje konto.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const _FullLoginPage()));
              },
              child: const Text('PRZEJDŹ DO LOGOWANIA',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    letterSpacing: 2)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anuluj',
              style: TextStyle(color: Color(0xFF555555), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// Pełna strona logowania (osobna trasa)
class _FullLoginPage extends StatelessWidget {
  const _FullLoginPage();
  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PRZYCISKI SZUKAJ
// ═══════════════════════════════════════════════════════════════════════
class _SearchButton extends StatefulWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _SearchButton({required this.label, required this.primary,
      required this.onTap});
  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter:  (_) => setState(() => _hovered = true),
      onExit:   (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 50,
          decoration: BoxDecoration(
            color: widget.primary
                ? (_hovered ? const Color(0xFFEEEEEE) : Colors.white)
                : (_hovered ? const Color(0xFF222222) : AppColors.field),
            borderRadius: BorderRadius.circular(12),
            border: widget.primary ? null
                : Border.all(color: AppColors.fieldBorder, width: 1),
          ),
          child: Center(child: Text(widget.label, style: TextStyle(
            color: widget.primary ? AppColors.btnText : AppColors.textSecondary,
            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2,
          ))),
        ),
      ),
    );
  }
}
