import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cars_page.dart';
import 'search_page.dart';

// ═══════════════════════════════════════════════════════════════════════
// KOLORY
// ═══════════════════════════════════════════════════════════════════════
class C {
  static const bg           = Color(0xFF0A0A0A);
  static const sidebar      = Color(0xFF0F0F0F);
  static const sidebarBorder= Color(0xFF1A1A1A);
  static const card         = Color(0xFF141414);
  static const cardBorder   = Color(0xFF222222);
  static const field        = Color(0xFF181818);
  static const fieldBorder  = Color(0xFF2A2A2A);
  static const fieldActive  = Color(0xFF484848);
  static const text         = Color(0xFFFFFFFF);
  static const textSub      = Color(0xFF888888);
  static const textMuted    = Color(0xFF444444);
  static const divider      = Color(0xFF1A1A1A);
  static const success      = Color(0xFF55CC88);
  static const error        = Color(0xFFFF5555);
}

// ═══════════════════════════════════════════════════════════════════════
// STRONY
// ═══════════════════════════════════════════════════════════════════════
enum AppPage { search, cars, terms, pricing, login, account }

// ═══════════════════════════════════════════════════════════════════════
// JEDNORAZOWY EKRAN POWITALNY
// ═══════════════════════════════════════════════════════════════════════
class WelcomeOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  const WelcomeOverlay({super.key, required this.onDismiss});
  @override
  State<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<WelcomeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset>  _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
        begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black.withOpacity(0.80),
        child: Center(
          child: SlideTransition(
            position: _slide,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: C.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: C.cardBorder, width: 1),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      color: C.field,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.fieldBorder, width: 1),
                    ),
                    child: const Icon(Icons.directions_car_outlined,
                        color: C.text, size: 26),
                  ),
                  const SizedBox(height: 20),
                  const Text('Witaj w Wypożyczalni Aut', style: TextStyle(
                    color: C.text, fontSize: 20,
                    fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  const SizedBox(height: 10),
                  const Text(
                    'Przeglądaj naszą flotę, sprawdzaj dostępność i rezerwuj '
                    'samochody online. Logowanie wymagane jest jedynie przy '
                    'składaniu rezerwacji.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: C.textSub, fontSize: 13,
                        fontWeight: FontWeight.w300, height: 1.6)),
                  const Divider(color: C.divider, height: 36),
                  Row(children: [
                    _WelcomeFeature(icon: Icons.search_rounded,
                        label: 'Wyszukaj\nauto'),
                    _WelcomeFeature(icon: Icons.local_offer_outlined,
                        label: 'Zniżki\ni promocje'),
                    _WelcomeFeature(icon: Icons.calendar_today_outlined,
                        label: 'Zarezerwuj\nonline'),
                  ]),
                  const SizedBox(height: 28),
                  _PrimaryBtn(label: 'WEJDŹ DO SERWISU',
                      loading: false, onTap: _dismiss),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _WelcomeFeature({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: C.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.fieldBorder, width: 1)),
      child: Icon(icon, color: C.textSub, size: 18),
    ),
    const SizedBox(height: 8),
    Text(label, textAlign: TextAlign.center,
      style: const TextStyle(color: C.textMuted, fontSize: 11,
          fontWeight: FontWeight.w300)),
  ]));
}

// ═══════════════════════════════════════════════════════════════════════
// GŁÓWNA POWŁOKA APLIKACJI
// ═══════════════════════════════════════════════════════════════════════
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppPage _page = AppPage.search;
  bool _showWelcome = true;

  bool get _loggedIn =>
      Supabase.instance.client.auth.currentUser != null;

  String get _username {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return '';
    return user.email?.split('@').first ?? '';
  }

  void _go(AppPage p) => setState(() => _page = p);

  void _onUserTap() {
    if (_loggedIn) {
      _go(AppPage.account);
    } else {
      _go(AppPage.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: C.bg,
      // Dolna nawigacja na mobile
      bottomNavigationBar: isMobile ? _BottomNav(
        page: _page,
        loggedIn: _loggedIn,
        username: _username,
        onNav: _go,
        onUserTap: _onUserTap,
      ) : null,
      body: SafeArea(bottom: false, child: Stack(children: [
        Row(children: [
          // Sidebar tylko na desktop
          if (!isMobile) _Sidebar(
            page: _page,
            loggedIn: _loggedIn,
            username: _username,
            onNav: _go,
            onUserTap: _onUserTap,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _buildPage(),
            ),
          ),
        ]),
        if (_showWelcome)
          WelcomeOverlay(
              onDismiss: () => setState(() => _showWelcome = false)),
      ]),
      ),
    );
  }

  Widget _buildPage() {
    switch (_page) {
      case AppPage.search:
        return const SearchPage(key: ValueKey('search'));
      case AppPage.cars:
        return const CarsPage(key: ValueKey('cars'));
      case AppPage.terms:
        return const _TermsPage(key: ValueKey('terms'));
      case AppPage.pricing:
        return const _PricingPage(key: ValueKey('pricing'));
      case AppPage.login:
        return _LoginPage(
            key: const ValueKey('login'),
            onSuccess: () {
              setState(() => _page = AppPage.account);
            },
            onCancel: () => _go(AppPage.search));
      case AppPage.account:
        return _AccountPage(
            key: const ValueKey('account'),
            username: _username,
            email: Supabase.instance.client.auth.currentUser?.email ?? '',
            onLogout: () async {
              await Supabase.instance.client.auth.signOut();
              setState(() => _page = AppPage.search);
            });
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SIDEBAR
// ═══════════════════════════════════════════════════════════════════════
class _Sidebar extends StatelessWidget {
  final AppPage page;
  final bool loggedIn;
  final String username;
  final ValueChanged<AppPage> onNav;
  final VoidCallback onUserTap;

  const _Sidebar({
    required this.page,
    required this.loggedIn,
    required this.username,
    required this.onNav,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: C.sidebar,
        border: Border(right: BorderSide(color: C.sidebarBorder, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),

          // ── IKONA UŻYTKOWNIKA (górna, większa) ───────────────────────
          _UserIcon(
            loggedIn: loggedIn,
            username: username,
            active: page == AppPage.login || page == AppPage.account,
            onTap: onUserTap,
          ),

          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            color: C.divider,
          ),

          // ── NAWIGACJA ────────────────────────────────────────────────
          _SidebarItem(
            icon: Icons.search_rounded,
            tooltip: 'Szukaj',
            active: page == AppPage.search,
            onTap: () => onNav(AppPage.search),
          ),
          _SidebarItem(
            icon: Icons.directions_car_outlined,
            tooltip: 'Wszystkie auta',
            active: page == AppPage.cars,
            onTap: () => onNav(AppPage.cars),
          ),
          _SidebarItem(
            icon: Icons.description_outlined,
            tooltip: 'Regulamin',
            active: page == AppPage.terms,
            onTap: () => onNav(AppPage.terms),
          ),
          _SidebarItem(
            icon: Icons.local_offer_outlined,
            tooltip: 'Cennik & Zniżki',
            active: page == AppPage.pricing,
            onTap: () => onNav(AppPage.pricing),
          ),

          const Spacer(),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DOLNA NAWIGACJA (mobile)
// ═══════════════════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final AppPage page;
  final bool loggedIn;
  final String username;
  final ValueChanged<AppPage> onNav;
  final VoidCallback onUserTap;

  const _BottomNav({
    required this.page, required this.loggedIn, required this.username,
    required this.onNav, required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.sidebar,
        border: const Border(top: BorderSide(color: C.sidebarBorder, width: 1)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Row(children: [
        _BottomNavItem(
          icon: Icons.search_rounded,
          label: 'Szukaj',
          active: page == AppPage.search,
          onTap: () => onNav(AppPage.search),
        ),
        _BottomNavItem(
          icon: Icons.directions_car_outlined,
          label: 'Auta',
          active: page == AppPage.cars,
          onTap: () => onNav(AppPage.cars),
        ),
        _BottomNavItem(
          icon: Icons.description_outlined,
          label: 'Regulamin',
          active: page == AppPage.terms,
          onTap: () => onNav(AppPage.terms),
        ),
        _BottomNavItem(
          icon: Icons.local_offer_outlined,
          label: 'Cennik',
          active: page == AppPage.pricing,
          onTap: () => onNav(AppPage.pricing),
        ),
        // Konto / logowanie
        Expanded(
          child: GestureDetector(
            onTap: onUserTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: (page == AppPage.login || page == AppPage.account)
                          ? C.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: loggedIn
                            ? Colors.white.withOpacity(
                                (page == AppPage.account) ? 0.3 : 0.15)
                            : C.sidebarBorder,
                        width: 1),
                    ),
                    child: Center(
                      child: loggedIn
                          ? Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: (page == AppPage.account)
                                    ? C.text : C.textSub,
                                fontSize: 13,
                                fontWeight: FontWeight.w600))
                          : Icon(Icons.person_outline,
                              color: (page == AppPage.login)
                                  ? C.text : C.textMuted,
                              size: 17),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loggedIn ? username.split('').take(6).join() : 'Konto',
                    style: TextStyle(
                      color: (page == AppPage.login || page == AppPage.account)
                          ? C.text : C.textMuted,
                      fontSize: 9, fontWeight: FontWeight.w400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _BottomNavItem({required this.icon, required this.label,
      required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: active ? C.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: active
                      ? Border.all(color: C.cardBorder, width: 1)
                      : null,
                ),
                child: Center(
                  child: Icon(icon,
                    size: 18,
                    color: active ? C.text : C.textMuted),
                ),
              ),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(
                color: active ? C.text : C.textMuted,
                fontSize: 9, fontWeight: FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}

// Ikona użytkownika
class _UserIcon extends StatefulWidget {
  final bool loggedIn;
  final String username;
  final bool active;
  final VoidCallback onTap;
  const _UserIcon({required this.loggedIn, required this.username,
      required this.active, required this.onTap});
  @override
  State<_UserIcon> createState() => _UserIconState();
}

class _UserIconState extends State<_UserIcon> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.loggedIn
              ? 'Konto (${widget.username})' : 'Zaloguj się',
          preferBelow: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: _hovered ? 42 : 38,
            height: _hovered ? 42 : 38,
            margin: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: widget.active
                  ? C.card
                  : (_hovered ? C.card : Colors.transparent),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: widget.loggedIn
                    ? (widget.active
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.15))
                    : (_hovered ? C.fieldBorder : C.sidebarBorder),
                width: 1,
              ),
            ),
            child: Center(
              child: widget.loggedIn
                  ? Text(
                      widget.username.isNotEmpty
                          ? widget.username[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: C.text,
                        fontSize: _hovered ? 17 : 15,
                        fontWeight: FontWeight.w600,
                      ))
                  : Icon(Icons.person_outline,
                      color: _hovered ? C.textSub : C.textMuted,
                      size: _hovered ? 22 : 20),
            ),
          ),
        ),
      ),
    );
  }
}

// Pozycja nawigacji
class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  const _SidebarItem({required this.icon, required this.tooltip,
      required this.active, required this.onTap});
  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          preferBelow: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: _hovered ? 40 : 36,
            height: _hovered ? 40 : 36,
            margin: EdgeInsets.symmetric(
                horizontal: _hovered ? 10 : 12, vertical: 3),
            decoration: BoxDecoration(
              color: widget.active
                  ? C.card
                  : (_hovered ? C.sidebarBorder.withOpacity(0.4)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: widget.active
                  ? Border.all(color: C.cardBorder, width: 1) : null,
            ),
            child: Center(
              child: AnimatedScale(
                scale: _hovered ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Icon(
                  widget.icon,
                  size: 19,
                  color: widget.active
                      ? C.text
                      : (_hovered ? C.textSub : C.textMuted),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// STRONA WYSZUKIWANIA (placeholder na razie)
// ═══════════════════════════════════════════════════════════════════════
class _SearchPage extends StatelessWidget {
  const _SearchPage({super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 20 : 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Witaj w wypożyczalni', style: TextStyle(
            color: C.text, fontSize: 28, fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          )),
          const SizedBox(height: 8),
          const Text('Wyszukaj auto i zarezerwuj już dziś',
            style: TextStyle(color: C.textSub, fontSize: 15,
                fontWeight: FontWeight.w300)),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.cardBorder, width: 1),
            ),
            child: const Center(
              child: Text('Wyszukiwarka — wkrótce',
                style: TextStyle(color: C.textMuted, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// LISTA AUT (placeholder)
// ═══════════════════════════════════════════════════════════════════════
class _CarsPlaceholder extends StatelessWidget {
  const _CarsPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.directions_car_outlined, color: C.textMuted, size: 40),
      SizedBox(height: 16),
      Text('Lista aut', style: TextStyle(color: C.textSub,
          fontSize: 16, fontWeight: FontWeight.w300)),
      SizedBox(height: 6),
      Text('Wkrótce', style: TextStyle(color: C.textMuted, fontSize: 13)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// REGULAMIN
// ═══════════════════════════════════════════════════════════════════════
class _TermsPage extends StatelessWidget {
  const _TermsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 48, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PageHeader(icon: Icons.description_outlined,
            title: 'Regulamin Wypożyczalni Aut',
            subtitle: 'Obowiązuje od 1 stycznia 2025 r.'),
          const SizedBox(height: 36),
          _TermsSection(title: '§ 1. Postanowienia ogólne', items: [
            '1.1. Niniejszy Regulamin określa zasady wynajmu pojazdów przez Wypożyczalnię Aut, zwaną dalej „Wypożyczalnią".',
            '1.2. Wynajmującym może być wyłącznie osoba pełnoletnia posiadająca ważne prawo jazdy odpowiedniej kategorii, wydane co najmniej 2 lata przed datą wynajmu.',
            '1.3. Zawarcie umowy najmu pojazdu następuje po weryfikacji tożsamości Wynajmującego, okazaniu ważnego dokumentu tożsamości oraz prawa jazdy.',
            '1.4. Wypożyczalnia zastrzega sobie prawo do odmowy wynajmu pojazdu bez podania przyczyny.',
            '1.5. Minimalny wiek Wynajmującego wynosi 21 lat. Dla pojazdów o mocy powyżej 200 KM minimalny wiek wynosi 25 lat.',
          ]),
          _TermsSection(title: '§ 2. Warunki najmu', items: [
            '2.1. Wynajem pojazdu odbywa się na podstawie pisemnej umowy najmu zawartej pomiędzy Wypożyczalnią a Wynajmującym.',
            '2.2. Wynajmujący zobowiązany jest do podania prawdziwych danych osobowych, w tym aktualnego adresu zamieszkania i numeru telefonu.',
            '2.3. Minimalny okres najmu wynosi 1 dobę. Przez dobę rozumie się 24 godziny od momentu przekazania pojazdu.',
            '2.4. Pojazd wydawany jest Wynajmującemu z pełnym bakiem paliwa. Wynajmujący zobowiązany jest zwrócić pojazd z pełnym bakiem lub pokryć koszt paliwa wg aktualnych cen rynkowych powiększony o opłatę manipulacyjną w wysokości 30 zł.',
            '2.5. Przekroczenie umówionego terminu zwrotu pojazdu bez uprzedniego poinformowania Wypożyczalni skutkuje naliczeniem opłaty w wysokości 150% stawki dobowej za każdą rozpoczętą dobę opóźnienia.',
            '2.6. Pojazd może być użytkowany wyłącznie na terytorium Rzeczypospolitej Polskiej, chyba że umowa stanowi inaczej.',
          ]),
          _TermsSection(title: '§ 3. Kaucja i płatności', items: [
            '3.1. Warunkiem wydania pojazdu jest wpłata kaucji zwrotnej, której wysokość uzależniona jest od klasy wynajmowanego pojazdu.',
            '3.2. Kaucja zwracana jest Wynajmującemu w ciągu 3 dni roboczych od zwrotu pojazdu, po stwierdzeniu braku uszkodzeń i roszczeń.',
            '3.3. Wypożyczalnia akceptuje płatności kartą kredytową/debetową, przelewem bankowym oraz gotówką.',
            '3.4. W przypadku szkody przewyższającej wartość kaucji, Wynajmujący zobowiązany jest do pokrycia różnicy.',
          ]),
          _TermsSection(title: '§ 4. Obowiązki Wynajmującego', items: [
            '4.1. Wynajmujący zobowiązuje się do użytkowania pojazdu zgodnie z jego przeznaczeniem i instrukcją obsługi.',
            '4.2. Wynajmujący zobowiązany jest do przestrzegania przepisów ruchu drogowego i ponosi pełną odpowiedzialność za mandaty i kary nałożone w czasie trwania najmu.',
            '4.3. Zabronione jest: przewożenie ładunków przekraczających dopuszczalną ładowność, palenie tytoniu i e-papierosów w pojeździe, przewożenie zwierząt bez specjalnego zabezpieczenia, uczestnictwo w wyścigach i rajdach, nauka jazdy.',
            '4.4. Wynajmujący zobowiązany jest do niezwłocznego poinformowania Wypożyczalni o każdej kolizji, wypadku lub kradzieży pojazdu oraz zabezpieczenia pojazdu i wezwania Policji.',
          ]),
          _TermsSection(title: '§ 5. Odpowiedzialność za szkody', items: [
            '5.1. Wynajmujący ponosi pełną odpowiedzialność za wszelkie szkody powstałe w czasie trwania najmu, niezależnie od ich przyczyny.',
            '5.2. Każdy pojazd objęty jest ubezpieczeniem OC i AC. Udział własny Wynajmującego w szkodzie wynosi do 2 000 zł dla pojazdów standardowych i do 5 000 zł dla pojazdów premium.',
            '5.3. Wynajmujący odpowiada całkowicie za szkody powstałe w wyniku: jazdy pod wpływem alkoholu lub środków odurzających, celowego uszkodzenia pojazdu.',
            '5.4. Za szkody stwierdzone po zwrocie pojazdu, nieujawnione w protokole zdawczo-odbiorczym, odpowiedzialność Wynajmującego wygasa po 24 godzinach od zwrotu pojazdu.',
          ]),
          _TermsSection(title: '§ 6. Rozwiązanie umowy', items: [
            '6.1. Wypożyczalnia zastrzega sobie prawo do natychmiastowego rozwiązania umowy najmu w przypadku: stwierdzenia naruszenia warunków niniejszego Regulaminu, podejrzenia popełnienia przestępstwa z użyciem pojazdu.',
            '6.2. Wynajmujący może skrócić okres najmu bez dodatkowych opłat, powiadamiając Wypożyczalnię z minimum 24-godzinnym wyprzedzeniem. Opłata pobrana za niewykorzystany okres zostanie zwrócona w ciągu 5 dni roboczych.',
            '6.3. W przypadku rezygnacji z najmu do 24 godzin przed jego rozpoczęciem pobierana jest opłata manipulacyjna w wysokości 20% wartości zamówienia.',
          ]),
          _TermsSection(title: '§ 7. Postanowienia końcowe', items: [
            '7.1. W sprawach nieuregulowanych niniejszym Regulaminem zastosowanie mają przepisy Kodeksu Cywilnego.',
            '7.2. Wszelkie spory wynikające z zawartej umowy najmu rozstrzygane będą przez sąd właściwy miejscowo dla siedziby Wypożyczalni.',
            '7.3. Wypożyczalnia zastrzega sobie prawo do zmiany Regulaminu. O zmianach Klienci informowani są z 14-dniowym wyprzedzeniem.',
            '7.4. Regulamin wchodzi w życie z dniem 1 stycznia 2025 r.',
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CENNIK I ZNIŻKI
// ═══════════════════════════════════════════════════════════════════════
class _PricingPage extends StatelessWidget {
  const _PricingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 48, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PageHeader(icon: Icons.local_offer_outlined,
            title: 'Cennik & Zniżki',
            subtitle: 'Obowiązuje od 1 stycznia 2025 r.'),
          const SizedBox(height: 36),

          _SectionHeader(title: 'Zniżki za długość najmu'),
          const SizedBox(height: 12),
          const Text(
            'Im dłuższy najem, tym większa zniżka od ceny bazowej dobowej. '
            'Zniżka naliczana jest automatycznie dla całego okresu najmu.',
            style: TextStyle(color: C.textSub, fontSize: 13,
                fontWeight: FontWeight.w300, height: 1.6)),
          const SizedBox(height: 16),
          _DiscountTable(rows: const [
            _DR('1–2 doby',   'cena bazowa',            '0%',   false),
            _DR('3–6 dób',    'cena bazowa − 10%',      '10%',  false),
            _DR('7–13 dób',   'cena bazowa − 20%',      '20%',  false),
            _DR('14–21 dób',  'cena bazowa − 30%',      '30%',  true),
            _DR('22–30 dób',  'cena bazowa − 40%',      '40%',  true),
          ]),
          const SizedBox(height: 8),
          const Text(
            '* Pojazdy luksusowe i premium preferowane do najmu krótkoterminowego (1–7 dób).',
            style: TextStyle(color: C.textMuted, fontSize: 11,
                fontWeight: FontWeight.w300)),
          const SizedBox(height: 32),

          _SectionHeader(title: 'Zniżki dla Honorowych Dawców Krwi'),
          const SizedBox(height: 12),
          const Text(
            'Wypożyczalnia z dumą wspiera Honorowych Dawców Krwi. '
            'Zniżka HDK sumuje się ze zniżką za długość najmu — '
            'łączna zniżka nie może jednak przekroczyć 55%.',
            style: TextStyle(color: C.textSub, fontSize: 13,
                fontWeight: FontWeight.w300, height: 1.6)),
          const SizedBox(height: 16),
          _HdkCard(
            level: 'Zasłużony Honorowy Dawca Krwi I stopnia',
            color: const Color(0xFFFFD700),
            requirement: 'Kobiety: min. 15 l | Mężczyźni: min. 18 l oddanej krwi',
            discount: '20%',
            description: 'Najwyższy stopień — przyznawany przez Prezydenta RP za '
                'szczególnie zasłużone krwiodawstwo.',
          ),
          const SizedBox(height: 10),
          _HdkCard(
            level: 'Zasłużony Honorowy Dawca Krwi II stopnia',
            color: const Color(0xFFC0C0C0),
            requirement: 'Kobiety: min. 10 l | Mężczyźni: min. 12 l oddanej krwi',
            discount: '15%',
            description: 'Przyznawany przez Ministra Zdrowia za długoletnią '
                'i systematyczną działalność krwiodawczą.',
          ),
          const SizedBox(height: 10),
          _HdkCard(
            level: 'Zasłużony Honorowy Dawca Krwi III stopnia',
            color: const Color(0xFFCD7F32),
            requirement: 'Kobiety: min. 5 l | Mężczyźni: min. 6 l oddanej krwi',
            discount: '10%',
            description: 'Pierwszy stopień odznaczenia, przyznawany przez Zarząd PCK '
                'za aktywne krwiodawstwo.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: C.field,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: C.fieldBorder, width: 1)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: C.textSub, size: 16),
              const SizedBox(width: 10),
              const Expanded(child: Text(
                'Aby skorzystać ze zniżki HDK, okaż aktualną legitymację '
                'w momencie odbioru pojazdu lub prześlij jej skan podczas '
                'rezerwacji. Zniżka przypisywana jest do konta jednorazowo.',
                style: TextStyle(color: C.textSub, fontSize: 12,
                    fontWeight: FontWeight.w300, height: 1.6))),
            ]),
          ),
          const SizedBox(height: 32),

          _SectionHeader(title: 'Przykłady obliczenia ceny'),
          const SizedBox(height: 16),
          _ExampleCard(
            title: 'BMW Seria 3 · 10 dób · ZHDK II stopnia',
            basePrice: 350, days: 10,
            durationDiscount: 20, hdkDiscount: 15),
          const SizedBox(height: 10),
          _ExampleCard(
            title: 'Toyota Corolla · 14 dób · bez zniżki HDK',
            basePrice: 180, days: 14,
            durationDiscount: 30, hdkDiscount: 0),
          const SizedBox(height: 10),
          _ExampleCard(
            title: 'Porsche 911 · 7 dób · ZHDK I stopnia',
            basePrice: 1500, days: 7,
            durationDiscount: 20, hdkDiscount: 20),
          const SizedBox(height: 32),

          _SectionHeader(title: 'Pozostałe zniżki'),
          const SizedBox(height: 16),
          _DiscountTable(rows: const [
            _DR('Stały klient (min. 5 wynajmów)',        '5% od ceny końcowej',  '5%', false),
            _DR('Rezerwacja z 7-dniowym wyprzedzeniem',  'Dodatkowe 5%',         '5%', false),
            _DR('Emeryt / Rencista (powyżej 65 lat)',    'W dni robocze',        '8%', false),
            _DR('Student (ważna legitymacja)',           'Pojazdy ekonomiczne',  '7%', false),
          ]),
          const SizedBox(height: 12),
          const Text(
            'Zniżki nie łączą się ze sobą, z wyjątkiem zniżki za długość najmu '
            'oraz zniżki HDK, które sumują się zgodnie z zasadami powyżej.',
            style: TextStyle(color: C.textMuted, fontSize: 12,
                fontWeight: FontWeight.w300, height: 1.6)),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

// ─── KOMPONENTY STRON ─────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _PageHeader({required this.icon, required this.title,
      required this.subtitle});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 48, height: 48,
      decoration: BoxDecoration(color: C.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.fieldBorder, width: 1)),
      child: Icon(icon, color: C.textSub, size: 22)),
    const SizedBox(width: 16),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: C.text, fontSize: 22,
          fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      const SizedBox(height: 2),
      Text(subtitle, style: const TextStyle(color: C.textMuted,
          fontSize: 12, fontWeight: FontWeight.w300)),
    ]),
  ]);
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 16,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(color: C.text, fontSize: 14,
        fontWeight: FontWeight.w600)),
  ]);
}

class _TermsSection extends StatelessWidget {
  final String title;
  final List<String> items;
  const _TermsSection({required this.title, required this.items});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(color: C.text, fontSize: 14,
        fontWeight: FontWeight.w600)),
    const SizedBox(height: 12),
    ...items.map((item) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 7),
          child: CircleAvatar(radius: 2,
              backgroundColor: Color(0xFF444444))),
        const SizedBox(width: 10),
        Expanded(child: Text(item, style: const TextStyle(
          color: C.textSub, fontSize: 13,
          fontWeight: FontWeight.w300, height: 1.6))),
      ]),
    )),
    Container(height: 1, color: C.divider,
        margin: const EdgeInsets.symmetric(vertical: 18)),
  ]);
}

class _DR {
  final String period, price, discount;
  final bool highlight;
  const _DR(this.period, this.price, this.discount, this.highlight);
}

class _DiscountTable extends StatelessWidget {
  final List<_DR> rows;
  const _DiscountTable({required this.rows});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.cardBorder, width: 1)),
      child: Column(children: rows.map((r) {
        final isLast = r == rows.last;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: r.highlight
                ? Colors.white.withOpacity(0.03) : Colors.transparent,
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(11))
                : null,
            border: !isLast
                ? const Border(bottom: BorderSide(color: C.divider, width: 1))
                : null),
          child: Row(children: [
            Expanded(flex: 3, child: Text(r.period, style: const TextStyle(
              color: C.text, fontSize: 13, fontWeight: FontWeight.w400))),
            Expanded(flex: 4, child: Text(r.price, style: const TextStyle(
              color: C.textSub, fontSize: 13, fontWeight: FontWeight.w300))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: r.highlight
                    ? C.success.withOpacity(0.12)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6)),
              child: Text(r.discount, style: TextStyle(
                color: r.highlight ? C.success : C.textSub,
                fontSize: 12, fontWeight: FontWeight.w600))),
          ]),
        );
      }).toList()),
    );
  }
}

class _HdkCard extends StatelessWidget {
  final String level, requirement, discount, description;
  final Color color;
  const _HdkCard({required this.level, required this.color,
      required this.requirement, required this.discount,
      required this.description});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: C.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2), width: 1)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3), width: 1)),
        child: Icon(Icons.favorite, color: color.withOpacity(0.8), size: 20)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(level, style: const TextStyle(
              color: C.text, fontSize: 13, fontWeight: FontWeight.w600))),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.3), width: 1)),
              child: Text('−$discount', style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 4),
          Text(requirement, style: const TextStyle(
            color: C.textMuted, fontSize: 11, fontWeight: FontWeight.w300)),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(
            color: C.textSub, fontSize: 12,
            fontWeight: FontWeight.w300, height: 1.5)),
        ])),
    ]),
  );
}

class _ExampleCard extends StatelessWidget {
  final String title;
  final double basePrice;
  final int days, durationDiscount, hdkDiscount;
  const _ExampleCard({required this.title, required this.basePrice,
      required this.days, required this.durationDiscount,
      required this.hdkDiscount});
  @override
  Widget build(BuildContext context) {
    final total = (durationDiscount + hdkDiscount).clamp(0, 55);
    final price = basePrice * (1 - total / 100);
    final sum   = price * days;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: C.field,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: C.fieldBorder, width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: C.text,
            fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _ExRow('Cena bazowa / doba', '${basePrice.toInt()} zł'),
        _ExRow('Liczba dób', '$days dób'),
        if (durationDiscount > 0)
          _ExRow('Zniżka za najem', '−$durationDiscount%'),
        if (hdkDiscount > 0)
          _ExRow('Zniżka HDK', '−$hdkDiscount%'),
        if (total > 0)
          _ExRow('Łączna zniżka', '−$total%'),
        Container(height: 1, color: C.divider,
            margin: const EdgeInsets.symmetric(vertical: 8)),
        _ExRow('Cena / doba po zniżce',
            '${price.toStringAsFixed(2)} zł', bold: true),
        _ExRow('RAZEM za $days dób',
            '${sum.toStringAsFixed(2)} zł', bold: true, green: true),
      ]),
    );
  }
}

class _ExRow extends StatelessWidget {
  final String label, value;
  final bool bold, green;
  const _ExRow(this.label, this.value, {this.bold = false, this.green = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(
        color: green ? C.text : C.textSub, fontSize: 12,
        fontWeight: bold ? FontWeight.w500 : FontWeight.w300))),
      Text(value, style: TextStyle(
        color: green ? C.success : C.text, fontSize: 12,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// STRONA LOGOWANIA / REJESTRACJI
// ═══════════════════════════════════════════════════════════════════════
class _LoginPage extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  const _LoginPage({super.key, required this.onSuccess, required this.onCancel});
  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> with TickerProviderStateMixin {

  bool _isRegister = false;
  bool _regSuccess = false;
  bool _isSubmitting = false;

  // Animacje pól rejestracji
  static const _fieldCount    = 4;
  static const _fieldDuration = Duration(milliseconds: 380);
  static const _fieldDelay    = Duration(milliseconds: 130);
  late final List<AnimationController> _fieldCtrls;
  late final List<Animation<double>>   _fieldFades;

  // Wejście
  late final AnimationController _enterCtrl;
  late final Animation<double> _enterFade;
  late final Animation<Offset>  _enterSlide;

  // Pola
  final _loginCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _pass2Ctrl  = TextEditingController();
  bool _showPass    = false;
  bool _showPass2   = false;
  bool _remember    = false;

  // Live check loginu
  bool? _loginAvailable;
  bool  _loginChecking = false;
  DateTime _lastCheck = DateTime(0);

  // Focus nodes
  final _fn1 = FocusNode();
  final _fn2 = FocusNode();
  final _fn3 = FocusNode();
  final _fn4 = FocusNode();

  // Błędy
  String? _loginError;
  String? _emailError;
  String? _passError;
  String? _pass2Error;
  String? _loginFormError; // błąd całego formularza logowania

  @override
  void initState() {
    super.initState();
    _fieldCtrls = List.generate(_fieldCount,
        (_) => AnimationController(vsync: this, duration: _fieldDuration));
    _fieldFades = _fieldCtrls.map((c) =>
        CurvedAnimation(parent: c, curve: Curves.easeOut)).toList();

    _enterCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _enterFade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterSlide = Tween<Offset>(
        begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl,
        curve: Curves.easeOutCubic));

    _loginCtrl.addListener(_onLoginChanged);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    for (final c in _fieldCtrls) c.dispose();
    _enterCtrl.dispose();
    _fn1.dispose(); _fn2.dispose(); _fn3.dispose(); _fn4.dispose();
    _loginCtrl.removeListener(_onLoginChanged);
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _emailCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _onLoginChanged() {
    if (!_isRegister) return;
    final val = _loginCtrl.text.trim();
    if (val.length < 3) {
      setState(() { _loginAvailable = null; _loginChecking = false; });
      return;
    }
    final now = DateTime.now();
    _lastCheck = now;
    setState(() { _loginChecking = true; _loginAvailable = null; });
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (_lastCheck != now || !mounted) return;
      try {
        final res = await Supabase.instance.client
            .from('uzytkownicy')
            .select('id')
            .eq('nazwa_uzytkownika', val);
        if (!mounted || _lastCheck != now) return;
        setState(() {
          _loginAvailable = (res as List).isEmpty;
          _loginChecking  = false;
        });
      } catch (_) {
        if (mounted && _lastCheck == now) {
          setState(() { _loginAvailable = true; _loginChecking = false; });
        }
      }
    });
  }

  Future<void> _goToRegister() async {
    for (final c in _fieldCtrls) c.reset();
    setState(() { _isRegister = true; _regSuccess = false; _loginFormError = null; });
    await Future.delayed(const Duration(milliseconds: 280));
    for (int i = 0; i < _fieldCount; i++) {
      await Future.delayed(_fieldDelay);
      if (mounted) _fieldCtrls[i].forward();
    }
  }

  Future<void> _goToLogin() async {
    if (_regSuccess) {
      _loginCtrl.clear(); _passCtrl.clear();
      _emailCtrl.clear(); _pass2Ctrl.clear();
      setState(() {
        _isRegister = false; _regSuccess = false;
        _loginAvailable = null;
        _loginError = _emailError = _passError = _pass2Error = null;
      });
      return;
    }
    for (int i = _fieldCount - 1; i >= 0; i--) {
      _fieldCtrls[i].reverse();
      await Future.delayed(const Duration(milliseconds: 40));
    }
    await Future.delayed(const Duration(milliseconds: 380));
    if (mounted) setState(() {
      _isRegister = false; _loginAvailable = null;
      _loginError = _emailError = _passError = _pass2Error = null;
    });
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting) return;
    final loginInput = _loginCtrl.text.trim();
    final pass       = _passCtrl.text;
    if (loginInput.isEmpty || pass.isEmpty) {
      setState(() => _loginFormError = 'Wpisz login/e-mail i hasło');
      return;
    }
    setState(() { _isSubmitting = true; _loginFormError = null; });
    try {
      String email = loginInput;

      // Jeśli to nie jest email — szukaj po nazwie użytkownika
      if (!loginInput.contains('@')) {
        final res = await Supabase.instance.client
            .from('uzytkownicy')
            .select('email')
            .eq('nazwa_uzytkownika', loginInput)
            .limit(1);
        final list = res as List;
        if (list.isEmpty) {
          setState(() {
            _isSubmitting = false;
            _loginFormError = 'Nie znaleziono użytkownika o tym loginie';
          });
          return;
        }
        email = list.first['email'] as String;
      }

      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pass,
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        widget.onSuccess();
      }
    } on AuthException catch (e) {
      setState(() {
        _isSubmitting = false;
        _loginFormError = e.message.contains('Invalid')
            ? 'Błędny login lub hasło' : 'Błąd: ${e.message}';
      });
    } catch (e) {
      setState(() { _isSubmitting = false; _loginFormError = 'Błąd: $e'; });
    }
  }

  Future<void> _submitRegister() async {
    if (_isSubmitting) return;
    final login = _loginCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    final pass2 = _pass2Ctrl.text;

    setState(() {
      _loginError = login.isEmpty ? 'Login nie może być pusty'
          : (login.length < 3 ? 'Min. 3 znaki'
          : (_loginAvailable == false ? 'Login jest zajęty' : null));
      _emailError = email.isEmpty ? 'E-mail nie może być pusty'
          : (!email.contains('@') ? 'Nieprawidłowy e-mail' : null);
      _passError  = pass.isEmpty ? 'Hasło nie może być puste'
          : (pass.length < 6 ? 'Min. 6 znaków' : null);
      _pass2Error = pass2 != pass ? 'Hasła nie są identyczne' : null;
    });
    if (_loginError != null || _emailError != null ||
        _passError != null || _pass2Error != null) return;

    setState(() => _isSubmitting = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email, password: pass);
      if (res.user == null) throw Exception('Brak użytkownika');
      await Supabase.instance.client.from('uzytkownicy').insert({
        'id': res.user!.id,
        'nazwa_uzytkownika': login,
        'email': email,
        'rola': 'klient',
      });
      if (mounted) setState(() { _regSuccess = true; _isSubmitting = false; });
    } on AuthException catch (e) {
      setState(() {
        _isSubmitting = false;
        _emailError = e.message.contains('already')
            ? 'E-mail już zarejestrowany' : 'Błąd: ${e.message}';
      });
    } catch (e) {
      setState(() { _isSubmitting = false; _emailError = 'Błąd: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _enterFade,
      child: SlideTransition(
        position: _enterSlide,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 40, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      color: C.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.cardBorder, width: 1),
                    ),
                    child: const Icon(Icons.directions_car_outlined,
                        color: C.text, size: 24),
                  ),
                  const SizedBox(height: 16),
                  const Text('WYPOŻYCZALNIA', style: TextStyle(
                    color: C.text, fontSize: 18,
                    fontWeight: FontWeight.w700, letterSpacing: 5,
                  )),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 18, height: 1, color: C.textMuted),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('AUT', style: TextStyle(
                        color: C.textSub, fontSize: 10,
                        letterSpacing: 4, fontWeight: FontWeight.w300))),
                    Container(width: 18, height: 1, color: C.textMuted),
                  ]),
                  const SizedBox(height: 36),

                  // Karta
                  Container(
                    decoration: BoxDecoration(
                      color: C.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: C.cardBorder, width: 1),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.topCenter,
                      child: _regSuccess
                          ? _buildSuccess()
                          : _buildForm(),
                    ),
                  ),

                  // Anuluj
                  const SizedBox(height: 20),
                  _TxtBtn(label: '← Wróć do strony głównej',
                      onTap: widget.onCancel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 8),
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: C.success.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: C.success.withOpacity(0.4), width: 1),
        ),
        child: const Icon(Icons.check_rounded, color: C.success, size: 28),
      ),
      const SizedBox(height: 18),
      const Text('Konto utworzone!', style: TextStyle(
        color: C.text, fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Witaj ${_loginCtrl.text.trim()}! Możesz się teraz zalogować.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: C.textSub, fontSize: 13,
            fontWeight: FontWeight.w300)),
      const SizedBox(height: 24),
      _PrimaryBtn(label: 'ZALOGUJ SIĘ', loading: false, onTap: _goToLogin),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nagłówek
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          child: _isRegister
              ? Row(key: const ValueKey('rh'), children: [
                  _BackBtn(onTap: _goToLogin),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Utwórz konto', style: TextStyle(
                        color: C.text, fontSize: 17,
                        fontWeight: FontWeight.w600)),
                      Text('Dołącz do wypożyczalni', style: TextStyle(
                        color: C.textSub, fontSize: 12,
                        fontWeight: FontWeight.w300)),
                    ],
                  ),
                ])
              : Column(key: const ValueKey('lh'),
                  crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('Zaloguj się', style: TextStyle(
                    color: C.text, fontSize: 17, fontWeight: FontWeight.w600)),
                  SizedBox(height: 3),
                  Text('Witaj ponownie', style: TextStyle(
                    color: C.textSub, fontSize: 12,
                    fontWeight: FontWeight.w300)),
                ]),
        ),
        const SizedBox(height: 22),

        // Pole loginu
        _Field(
          controller: _loginCtrl,
          label: _isRegister ? 'Login' : 'Login lub e-mail',
          icon: Icons.person_outline,
          focusNode: _fn1,
          nextFocus: _isRegister ? _fn2 : _fn3,
          errorText: _isRegister ? _loginError : null,
          suffix: _isRegister ? _loginSuffix() : null,
        ),

        // Email (tylko rejestracja)
        _staggered(0, Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _Field(
            controller: _emailCtrl,
            label: 'Adres e-mail',
            icon: Icons.mail_outline,
            focusNode: _fn2,
            nextFocus: _fn3,
            keyboardType: TextInputType.emailAddress,
            errorText: _emailError,
          ),
        )),

        const SizedBox(height: 12),

        // Hasło
        _Field(
          controller: _passCtrl,
          label: 'Hasło',
          icon: Icons.lock_outline,
          obscure: !_showPass,
          focusNode: _fn3,
          nextFocus: _isRegister ? _fn4 : null,
          errorText: _isRegister ? _passError : null,
          suffix: _EyeBtn(visible: _showPass,
              onTap: () => setState(() => _showPass = !_showPass)),
        ),

        // Powtórz hasło (tylko rejestracja)
        _staggered(1, Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _Field(
            controller: _pass2Ctrl,
            label: 'Powtórz hasło',
            icon: Icons.lock_outline,
            obscure: !_showPass2,
            focusNode: _fn4,
            errorText: _pass2Error,
            suffix: _EyeBtn(visible: _showPass2,
                onTap: () => setState(() => _showPass2 = !_showPass2)),
          ),
        )),

        const SizedBox(height: 16),

        if (!_isRegister) ...[
          _CheckRow(value: _remember, label: 'Zapamiętaj mnie',
              onTap: () => setState(() => _remember = !_remember)),
          if (_loginFormError != null) ...[
            const SizedBox(height: 10),
            Text(_loginFormError!, style: const TextStyle(
              color: C.error, fontSize: 12, fontWeight: FontWeight.w300)),
          ],
          const SizedBox(height: 20),
          _PrimaryBtn(label: 'ZALOGUJ SIĘ',
              loading: _isSubmitting, onTap: _submitLogin),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Container(height: 1, color: C.fieldBorder)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('lub', style: TextStyle(
                  color: C.textMuted, fontSize: 11, letterSpacing: 1))),
            Expanded(child: Container(height: 1, color: C.fieldBorder)),
          ]),
          const SizedBox(height: 16),
          _SecondaryBtn(label: 'Utwórz konto', onTap: _goToRegister),
        ] else ...[
          _staggered(2, Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _PrimaryBtn(label: 'ZAREJESTRUJ SIĘ',
                loading: _isSubmitting, onTap: _submitRegister),
          )),
          _staggered(3, Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(child: _TxtBtn(
                label: '← Wróć do logowania', onTap: _goToLogin)),
          )),
        ],
      ],
    );
  }

  Widget? _loginSuffix() {
    if (_loginCtrl.text.trim().length < 3) return null;
    if (_loginChecking) {
      return const Padding(padding: EdgeInsets.only(right: 14),
        child: SizedBox(width: 14, height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: C.textMuted)));
    }
    if (_loginAvailable == true) {
      return const Padding(padding: EdgeInsets.only(right: 14),
        child: Icon(Icons.check_circle_outline, color: C.success, size: 17));
    }
    if (_loginAvailable == false) {
      return const Padding(padding: EdgeInsets.only(right: 14),
        child: Icon(Icons.cancel_outlined, color: C.error, size: 17));
    }
    return null;
  }

  Widget _staggered(int i, Widget child) {
    if (!_isRegister) return const SizedBox.shrink();
    return SizeTransition(
      sizeFactor: CurvedAnimation(
          parent: _fieldCtrls[i], curve: Curves.easeInOutCubic),
      axisAlignment: -1,
      child: FadeTransition(opacity: _fieldFades[i], child: child),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// STRONA KONTA
// ═══════════════════════════════════════════════════════════════════════
class _AccountPage extends StatefulWidget {
  final String username;
  final String email;
  final VoidCallback onLogout;
  const _AccountPage({super.key, required this.username,
      required this.email, required this.onLogout});
  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) { setState(() => _loading = false); return; }

      final res = await Supabase.instance.client
          .from('wypozyczenia')
          .select('''
            id, id_samochodu, liczba_dni, cena_calkowita, status,
            data_rozpoczecia, data_zakonczenia,
            samochody (
              modele ( nazwa, marki ( nazwa ) )
            )
          ''')
          .eq('id_uzytkownika', user.id)
          .order('data_rozpoczecia', ascending: false);

      if (mounted) setState(() {
        _history = (res as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(String iso) {
    final d = DateTime.parse(iso);
    return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
  }

  String _carName(Map h) {
    try {
      return '${h['samochody']['modele']['marki']['nazwa']} '
             '${h['samochody']['modele']['nazwa']}';
    } catch (_) { return '—'; }
  }

  Future<void> _returnCar(Map<String, dynamic> h, String newStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: newStatus == 'zakonczone' ? 'Zwrot auta' : 'Anuluj rezerwację',
        message: newStatus == 'zakonczone'
            ? 'Czy na pewno chcesz oznaczyć wypożyczenie jako zakończone? '
              'Pamiętaj o fizycznym zwrocie kluczyków w biurze.'
            : 'Czy na pewno chcesz anulować tę rezerwację?',
        confirmLabel: newStatus == 'zakonczone' ? 'Zwróć' : 'Anuluj rezerwację',
        confirmColor: newStatus == 'zakonczone'
            ? C.success : const Color(0xFFFF5555),
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('wypozyczenia')
          .update({'status': newStatus})
          .eq('id', h['id'] as int);
      await Supabase.instance.client
          .from('samochody')
          .update({'status': 'dostepny'})
          .eq('id', h['id_samochodu'] as int);
      _loadHistory();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Błąd: $e'),
        backgroundColor: const Color(0xFF332222)));
    }
  }

  Future<void> _cancelRental(Map<String, dynamic> h) =>
      _returnCar(h, 'anulowane');

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 20 : 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Moje konto', style: TextStyle(
            color: C.text, fontSize: 26,
            fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 32),

          // Karta użytkownika
          Container(
            padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: C.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.cardBorder, width: 1)),
              child: Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.15), width: 1)),
                  child: Center(child: Text(
                    widget.username.isNotEmpty
                        ? widget.username[0].toUpperCase() : '?',
                    style: const TextStyle(color: C.text,
                        fontSize: 22, fontWeight: FontWeight.w600))),
                ),
                const SizedBox(width: 20),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.username, style: const TextStyle(
                      color: C.text, fontSize: 16,
                      fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(widget.email, style: const TextStyle(
                      color: C.textSub, fontSize: 13,
                      fontWeight: FontWeight.w300)),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: C.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: C.success.withOpacity(0.3), width: 1)),
                  child: const Text('klient', style: TextStyle(
                    color: C.success, fontSize: 11,
                    fontWeight: FontWeight.w500, letterSpacing: 0.5))),
              ]),
            ),
            const SizedBox(height: 20),

            // Historia wypożyczeń
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: C.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.cardBorder, width: 1)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('Historia wypożyczeń', style: TextStyle(
                      color: C.text, fontSize: 14,
                      fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (!_loading && _history.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: C.field,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: C.fieldBorder, width: 1)),
                        child: Text('${_history.length}', style: const TextStyle(
                          color: C.textSub, fontSize: 11))),
                  ]),
                  const SizedBox(height: 20),

                  if (_loading)
                    const Center(child: CircularProgressIndicator(
                        color: Color(0xFF555555), strokeWidth: 1.5))
                  else if (_history.isEmpty)
                    Column(children: [
                      const Icon(Icons.history,
                          color: C.textMuted, size: 32),
                      const SizedBox(height: 10),
                      const Text('Brak historii wypożyczeń',
                        style: TextStyle(color: C.textMuted,
                            fontSize: 13, fontWeight: FontWeight.w300)),
                      const SizedBox(height: 8),
                    ])
                  else
                    Column(children: _history.map((h) {
                      final status = h['status'] as String;
                      final statusColor = status == 'aktywne'
                          ? C.success
                          : (status == 'zakonczone'
                              ? C.textSub : const Color(0xFFFF5555));
                      final statusLabel = status == 'aktywne'
                          ? 'Aktywne'
                          : (status == 'zakonczone'
                              ? 'Zakończone' : 'Anulowane');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: C.field,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.fieldBorder, width: 1)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text(_carName(h),
                                style: const TextStyle(color: C.text,
                                    fontSize: 13, fontWeight: FontWeight.w600))),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: statusColor.withOpacity(0.3),
                                      width: 1)),
                                child: Text(statusLabel, style: TextStyle(
                                  color: statusColor, fontSize: 10,
                                  fontWeight: FontWeight.w600))),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.calendar_today_outlined,
                                  color: C.textMuted, size: 12),
                              const SizedBox(width: 6),
                              Text(
                                '${_fmt(h['data_rozpoczecia'])} – '
                                '${_fmt(h['data_zakonczenia'])}',
                                style: const TextStyle(color: C.textSub,
                                    fontSize: 12, fontWeight: FontWeight.w300)),
                              const SizedBox(width: 12),
                              Text('${h['liczba_dni']} dób',
                                style: const TextStyle(color: C.textMuted,
                                    fontSize: 11, fontWeight: FontWeight.w300)),
                              const Spacer(),
                              Text(
                                '${(h['cena_calkowita'] as num).toInt()} zł',
                                style: const TextStyle(color: C.text,
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            ]),

                            // Przyciski dla aktywnego wypożyczenia
                            if (status == 'aktywne') ...[
                              const SizedBox(height: 12),
                              Container(
                                height: 1, color: C.divider),
                              const SizedBox(height: 12),
                              Row(children: [
                                const Icon(Icons.info_outline,
                                    color: C.textMuted, size: 12),
                                const SizedBox(width: 6),
                                const Expanded(child: Text(
                                  'Zwrot wymaga wizyty w biurze w celu rozliczenia kaucji.',
                                  style: TextStyle(color: C.textMuted,
                                      fontSize: 10, fontWeight: FontWeight.w300))),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: _ReturnBtn(
                                    label: 'Zwróć auto',
                                    icon: Icons.keyboard_return,
                                    color: C.success,
                                    onTap: () => _returnCar(h, 'zakonczone'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _ReturnBtn(
                                    label: 'Anuluj rezerwację',
                                    icon: Icons.cancel_outlined,
                                    color: const Color(0xFFFF5555),
                                    onTap: () => _cancelRental(h),
                                  ),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      );
                    }).toList()),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _DangerBtn(label: 'Wyloguj się', onTap: widget.onLogout),
          ],
        ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// POLA I PRZYCISKI
// ═══════════════════════════════════════════════════════════════════════

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final FocusNode? focusNode;
  final FocusNode? nextFocus;
  final Widget? suffix;
  final String? errorText;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.focusNode,
    this.nextFocus,
    this.suffix,
    this.errorText,
    this.keyboardType,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(_onFocus);
  }
  void _onFocus() {
    if (mounted) setState(() => _focused = widget.focusNode!.hasFocus);
  }
  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocus);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _focused ? C.field : const Color(0x0CFFFFFF),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: hasError
                ? C.error.withOpacity(0.5)
                : (_focused ? C.fieldActive : C.fieldBorder),
            width: 1),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(widget.icon, size: 18,
            color: hasError ? C.error.withOpacity(0.6)
                : (_focused ? C.textSub : C.textMuted)),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: widget.controller,
            obscureText: widget.obscure,
            focusNode: widget.focusNode,
            keyboardType: widget.keyboardType,
            textInputAction: widget.nextFocus != null
                ? TextInputAction.next : TextInputAction.done,
            onSubmitted: (_) => widget.nextFocus?.requestFocus(),
            style: const TextStyle(color: C.text, fontSize: 14,
                fontWeight: FontWeight.w300, letterSpacing: 0.2),
            decoration: InputDecoration(
              hintText: widget.label,
              hintStyle: const TextStyle(color: C.textMuted,
                  fontSize: 14, fontWeight: FontWeight.w300),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            cursorColor: C.textSub, cursorWidth: 1,
          )),
          if (widget.suffix != null) widget.suffix!,
        ]),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        child: hasError
            ? Padding(
                padding: const EdgeInsets.only(top: 5, left: 4),
                child: Text(widget.errorText!, style: const TextStyle(
                  color: C.error, fontSize: 11,
                  fontWeight: FontWeight.w300)))
            : const SizedBox.shrink(),
      ),
    ]);
  }
}

class _PrimaryBtn extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.loading,
      required this.onTap});
  @override
  State<_PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<_PrimaryBtn> {
  bool _hovered = false, _pressed = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter:  (_) => setState(() => _hovered = true),
      onExit:   (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) => setState(() => _pressed = false),
        onTapCancel: ()  => setState(() => _pressed = false),
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 48,
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFFCCCCCC)
                : (_hovered ? const Color(0xFFEEEEEE) : Colors.white),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(child: widget.loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : Text(widget.label, style: const TextStyle(
                  color: Colors.black, fontSize: 12,
                  fontWeight: FontWeight.w700, letterSpacing: 2.5))),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryBtn({required this.label, required this.onTap});
  @override
  State<_SecondaryBtn> createState() => _SecondaryBtnState();
}

class _SecondaryBtnState extends State<_SecondaryBtn> {
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
          height: 48,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1E1E1E) : C.field,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: C.fieldBorder, width: 1),
          ),
          child: Center(child: Text(widget.label, style: const TextStyle(
            color: C.textSub, fontSize: 12,
            fontWeight: FontWeight.w500, letterSpacing: 1.5))),
        ),
      ),
    );
  }
}

class _DangerBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _DangerBtn({required this.label, required this.onTap});
  @override
  State<_DangerBtn> createState() => _DangerBtnState();
}

class _DangerBtnState extends State<_DangerBtn> {
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
          height: 48,
          decoration: BoxDecoration(
            color: _hovered
                ? C.error.withOpacity(0.12) : C.error.withOpacity(0.07),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: C.error.withOpacity(_hovered ? 0.4 : 0.2), width: 1),
          ),
          child: Center(child: Text(widget.label, style: TextStyle(
            color: C.error.withOpacity(_hovered ? 1.0 : 0.7),
            fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5))),
        ),
      ),
    );
  }
}

class _TxtBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TxtBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: const TextStyle(
          color: C.textSub, fontSize: 13, fontWeight: FontWeight.w300)),
      ),
    );
  }
}

class _EyeBtn extends StatelessWidget {
  final bool visible;
  final VoidCallback onTap;
  const _EyeBtn({required this.visible, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: visible ? C.textSub : C.textMuted, size: 18),
        ),
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: C.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.fieldBorder, width: 1),
          ),
          child: const Icon(Icons.arrow_back,
              color: C.textSub, size: 15),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final bool value;
  final String label;
  final VoidCallback onTap;
  const _CheckRow({required this.value, required this.label,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: value ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: value ? Colors.white : C.fieldBorder,
                width: 1.5),
            ),
            child: value
                ? const Icon(Icons.check, size: 10, color: Colors.black)
                : null,
          ),
          const SizedBox(width: 9),
          Text(label, style: const TextStyle(
            color: C.textSub, fontSize: 13,
            fontWeight: FontWeight.w300)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PRZYCISK ZWROTU
// ═══════════════════════════════════════════════════════════════════════
class _ReturnBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ReturnBtn({required this.label, required this.icon,
      required this.color, required this.onTap});
  @override
  State<_ReturnBtn> createState() => _ReturnBtnState();
}

class _ReturnBtnState extends State<_ReturnBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 38,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_hovered ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: widget.color.withOpacity(_hovered ? 0.4 : 0.2),
              width: 1)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(widget.icon, color: widget.color, size: 13),
          const SizedBox(width: 6),
          Text(widget.label, style: TextStyle(
            color: widget.color, fontSize: 11,
            fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// DIALOG POTWIERDZENIA
// ═══════════════════════════════════════════════════════════════════════
class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  const _ConfirmDialog({required this.title, required this.message,
      required this.confirmLabel, required this.confirmColor});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xFF141414),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(color: C.text,
            fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center,
          style: const TextStyle(color: C.textSub, fontSize: 13,
              fontWeight: FontWeight.w300, height: 1.5)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anuluj', style: TextStyle(color: C.textSub)))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor.withOpacity(0.15),
              foregroundColor: confirmColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: confirmColor.withOpacity(0.3))),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel, style: TextStyle(
                color: confirmColor, fontWeight: FontWeight.w600,
                fontSize: 12)))),
        ]),
      ]),
    ),
  );
}