import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AppThemeData {
  final String name;
  final Color main;
  final Color sidebar;
  final Color player;
  final Color card;
  final Color text;
  final Color subtext;
  final Color button;
  final Color buttonActive;
  final Color selectedRow;
  final Color highlight;
  final Color highlightElevated;
  final Color shadow;
  final Color notification;
  final Color notificationError;
  final Color tabActive;
  final Color misc;

  const AppThemeData({
    required this.name,
    required this.main,
    required this.sidebar,
    required this.player,
    required this.card,
    required this.text,
    required this.subtext,
    required this.button,
    required this.buttonActive,
    required this.selectedRow,
    required this.highlight,
    required this.highlightElevated,
    required this.shadow,
    required this.notification,
    required this.notificationError,
    required this.tabActive,
    required this.misc,
  });

  Color get border => shadow;
  Color get bgColor => main;
  Color get panelColor => main;
  Color get panelLight => card;
  Color get cardColor => card;
  Color get textPrimary => text;
  Color get textSecondary => subtext;
  Color get accent => button;
  Brightness get brightness => ThemeData.estimateBrightnessForColor(main);

  static const green = AppThemeData(
    name: 'Green',
    main: Color(0xFF0F0F0F),
    sidebar: Color(0xFF121212),
    player: Color(0xFF0F0F0F),
    card: Color(0xFF282828),
    text: Color(0xFFFFFFFF),
    subtext: Color(0xFFB3B3B3),
    button: Color(0xFF1DB954),
    buttonActive: Color(0xFF1ED760),
    selectedRow: Color(0xFF1A2A1A),
    highlight: Color(0xFF2A2A2A),
    highlightElevated: Color(0xFF333333),
    shadow: Color(0xFF333333),
    notification: Color(0xFF1DB954),
    notificationError: Color(0xFFE8173A),
    tabActive: Color(0xFF1A3321),
    misc: Color(0xFF7B4FE9),
  );

  static const red = AppThemeData(
    name: 'Red',
    main: Color(0xFF0D0808),
    sidebar: Color(0xFF130A0A),
    player: Color(0xFF0D0808),
    card: Color(0xFF2A1515),
    text: Color(0xFFFFFFFF),
    subtext: Color(0xFFB3A3A3),
    button: Color(0xFFE8173A),
    buttonActive: Color(0xFFFF3657),
    selectedRow: Color(0xFF32151A),
    highlight: Color(0xFF3A2020),
    highlightElevated: Color(0xFF4A2929),
    shadow: Color(0xFF3D2020),
    notification: Color(0xFFE8173A),
    notificationError: Color(0xFFFFA000),
    tabActive: Color(0xFF4A1C27),
    misc: Color(0xFFE08A3E),
  );

  static const dribbblishWhite = AppThemeData(
    name: 'Dribbblish White',
    main: Color(0xFFF5F7FA),
    sidebar: Color(0xFFE9EDF2),
    player: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF17202A),
    subtext: Color(0xFF5D6B78),
    button: Color(0xFF2E7DDE),
    buttonActive: Color(0xFF1F63B5),
    selectedRow: Color(0xFFDCEBFA),
    highlight: Color(0xFFE8EEF5),
    highlightElevated: Color(0xFFD7E0EA),
    shadow: Color(0xFFB9C5D1),
    notification: Color(0xFF2E7DDE),
    notificationError: Color(0xFFD64545),
    tabActive: Color(0xFFD9E9FA),
    misc: Color(0xFF7A56C2),
  );

  static const catppuccinLatte = AppThemeData(
    name: 'Catppuccin Latte',
    main: Color(0xFFEFF1F5),
    sidebar: Color(0xFFE6E9EF),
    player: Color(0xFFDCE0E8),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF4C4F69),
    subtext: Color(0xFF6C6F85),
    button: Color(0xFF1E66F5),
    buttonActive: Color(0xFF1554D1),
    selectedRow: Color(0xFFD9E5FF),
    highlight: Color(0xFFE1E5EC),
    highlightElevated: Color(0xFFCCD2DC),
    shadow: Color(0xFFBCC3D0),
    notification: Color(0xFF1E66F5),
    notificationError: Color(0xFFD20F39),
    tabActive: Color(0xFFDCE7FF),
    misc: Color(0xFF8839EF),
  );

  static const nord = AppThemeData(
    name: 'Nord',
    main: Color(0xFF2E3440),
    sidebar: Color(0xFF272C36),
    player: Color(0xFF242933),
    card: Color(0xFF3B4252),
    text: Color(0xFFECEFF4),
    subtext: Color(0xFFD8DEE9),
    button: Color(0xFF88C0D0),
    buttonActive: Color(0xFF8FBCBB),
    selectedRow: Color(0xFF3D5664),
    highlight: Color(0xFF434C5E),
    highlightElevated: Color(0xFF4C566A),
    shadow: Color(0xFF596579),
    notification: Color(0xFF88C0D0),
    notificationError: Color(0xFFBF616A),
    tabActive: Color(0xFF3C5965),
    misc: Color(0xFFB48EAD),
  );

  static const dracula = AppThemeData(
    name: 'Dracula',
    main: Color(0xFF282A36),
    sidebar: Color(0xFF21222C),
    player: Color(0xFF191A21),
    card: Color(0xFF44475A),
    text: Color(0xFFF8F8F2),
    subtext: Color(0xFFBFBFB2),
    button: Color(0xFFBD93F9),
    buttonActive: Color(0xFFFF79C6),
    selectedRow: Color(0xFF493F62),
    highlight: Color(0xFF3B3D4B),
    highlightElevated: Color(0xFF505365),
    shadow: Color(0xFF6272A4),
    notification: Color(0xFF50FA7B),
    notificationError: Color(0xFFFF5555),
    tabActive: Color(0xFF443C5B),
    misc: Color(0xFF8BE9FD),
  );

  static const drearyBib = AppThemeData(
    name: 'Dreary BIB',
    main: Color(0xFF202020),
    sidebar: Color(0xFF202020),
    player: Color(0xFF242424),
    card: Color(0xFF242424),
    text: Color(0xFF8BC34A),
    subtext: Color(0xFFB4B4B4),
    button: Color(0xFF537B25),
    buttonActive: Color(0xFF98DA4B),
    selectedRow: Color(0xFF2A3C17),
    highlight: Color(0xFF303030),
    highlightElevated: Color(0xFF353535),
    shadow: Color(0xFF000000),
    notification: Color(0xFF242424),
    notificationError: Color(0xFF242424),
    tabActive: Color(0xFF303030),
    misc: Color(0xFF8BC34A),
  );

  static const drearyDeeper = AppThemeData(
    name: 'Dreary Deeper',
    main: Color(0xFF040614),
    sidebar: Color(0xFF0F111A),
    player: Color(0xFF0F111A),
    card: Color(0xFF0F1118),
    text: Color(0xFF4F9A87),
    subtext: Color(0xFF406560),
    button: Color(0xFF0D3A2E),
    buttonActive: Color(0xFF106165),
    selectedRow: Color(0xFF040614),
    highlight: Color(0xFF0A1527),
    highlightElevated: Color(0xFF0F1118),
    shadow: Color(0xFF406560),
    notification: Color(0xFF051024),
    notificationError: Color(0xFF051024),
    tabActive: Color(0xFF0A1527),
    misc: Color(0xFF406560),
  );

  static const gruvboxMaterialDark = AppThemeData(
    name: 'Gruvbox Material Dark',
    main: Color(0xFF1D2021),
    sidebar: Color(0xFF282828),
    player: Color(0xFF282828),
    card: Color(0xFF504945),
    text: Color(0xFFFFDAB9),
    subtext: Color(0xFFB8BBC2),
    button: Color(0xFF98971A),
    buttonActive: Color(0xFFB8BB26),
    selectedRow: Color(0xFF7C6F64),
    highlight: Color(0xFF3C3836),
    highlightElevated: Color(0xFF665C54),
    shadow: Color(0xFF3C3836),
    notification: Color(0xFF282828),
    notificationError: Color(0xFFCC241D),
    tabActive: Color(0xFF504945),
    misc: Color(0xFFD8A657),
  );

  static const onepunchDark = AppThemeData(
    name: 'Onepunch Dark',
    main: Color(0xFF1D2021),
    sidebar: Color(0xFF1D2021),
    player: Color(0xFF1D2021),
    card: Color(0xFF32302F),
    text: Color(0xFFD5C4A1),
    subtext: Color(0xFFB8BB26),
    button: Color(0xFF8EC07C),
    buttonActive: Color(0xFF8EC07C),
    selectedRow: Color(0xFFD3869B),
    highlight: Color(0xFF32302F),
    highlightElevated: Color(0xFF32302F),
    shadow: Color(0xFF1D2021),
    notification: Color(0xFFFB4934),
    notificationError: Color(0xFFCC2418),
    tabActive: Color(0xFFFB4934),
    misc: Color(0xFF83A598),
  );

  static const all = [
    green,
    red,
    dribbblishWhite,
    catppuccinLatte,
    nord,
    dracula,
    drearyBib,
    drearyDeeper,
    gruvboxMaterialDark,
    onepunchDark,
  ];
}

class AppThemeNotifier extends ValueNotifier<AppThemeData> {
  AppThemeNotifier._() : super(AppThemeData.green);
  static final instance = AppThemeNotifier._();
  static const _storageKey = 'desktop_theme';

  void toggle() => value =
      value == AppThemeData.green ? AppThemeData.red : AppThemeData.green;

  void setTheme(AppThemeData theme) {
    value = theme;
    _saveTheme(theme);
  }

  static Future<void> restoreSavedTheme() async {
    final box = Hive.box('settings');
    final name = box.get(_storageKey);
    if (name is! String) return;

    final saved = AppThemeData.all.cast<AppThemeData?>().firstWhere(
          (theme) => theme?.name == name,
          orElse: () => null,
        );
    if (saved != null) {
      instance.value = saved;
    }
  }

  static Future<void> _saveTheme(AppThemeData theme) async {
    await Hive.box('settings').put(_storageKey, theme.name);
  }
}

class AppThemeScope extends InheritedWidget {
  final AppThemeData theme;

  const AppThemeScope({super.key, required this.theme, required super.child});

  static AppThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()?.theme ??
      AppThemeData.green;

  static AppThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()?.theme;

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) => theme != oldWidget.theme;
}

class AppThemeBuilder extends StatefulWidget {
  final Widget Function(BuildContext, AppThemeData) builder;

  const AppThemeBuilder({super.key, required this.builder});

  @override
  State<AppThemeBuilder> createState() => _AppThemeBuilderState();
}

class _AppThemeBuilderState extends State<AppThemeBuilder> {
  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_changed);
  }

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.instance.value;
    return AppThemeScope(
      theme: theme,
      child: widget.builder(context, theme),
    );
  }
}
