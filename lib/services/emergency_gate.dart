import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import '../theme/app_theme.dart';
import 'emergency_block_notice.dart';
import 'firebase_service.dart';

typedef CurrentVersionLoader = Future<String> Function();

enum _EmergencyBlock { none, appMoved, forceUpdate }

class _EmergencyState {
  const _EmergencyState({
    required this.block,
    required this.forceUpdate,
    required this.appMoved,
  });

  static const none = _EmergencyState(
    block: _EmergencyBlock.none,
    forceUpdate: ForceUpdateStatus.notRequired,
    appMoved: AppMovedStatus.notRequired,
  );

  final _EmergencyBlock block;
  final ForceUpdateStatus forceUpdate;
  final AppMovedStatus appMoved;
}

class HostEmergencyGate extends StatefulWidget {
  const HostEmergencyGate({
    required this.child,
    this.remoteConfig = const YallaRemoteConfigAdapter(),
    this.refresh,
    this.recheck,
    this.loadCurrentVersion = readInstalledAppVersion,
    this.refreshTimeout = const Duration(seconds: 4),
    super.key,
  });

  final Widget child;
  final GameKitRemoteConfig remoteConfig;
  final Future<void> Function()? refresh;
  final Listenable? recheck;

  /// Installed-version reader handed to the kit's [ForceUpdateService].
  /// Defaults to the kit's own PackageInfo reader; tests pass a stub.
  final CurrentVersionLoader loadCurrentVersion;
  final Duration refreshTimeout;

  @override
  State<HostEmergencyGate> createState() => _HostEmergencyGateState();
}

class _HostEmergencyGateState extends State<HostEmergencyGate>
    with WidgetsBindingObserver {
  _EmergencyState _state = _EmergencyState.none;
  final ValueNotifier<bool> _playbackBlocked = ValueNotifier<bool>(false);
  Future<void>? _checkInFlight;
  bool _checkAgain = false;
  bool _refreshAgain = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.recheck?.addListener(_onRecheck);
    unawaited(_check());
  }

  @override
  void didUpdateWidget(HostEmergencyGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recheck != widget.recheck) {
      oldWidget.recheck?.removeListener(_onRecheck);
      widget.recheck?.addListener(_onRecheck);
    }
    if (oldWidget.remoteConfig != widget.remoteConfig) {
      unawaited(_check());
    }
  }

  @override
  void dispose() {
    widget.recheck?.removeListener(_onRecheck);
    WidgetsBinding.instance.removeObserver(this);
    _playbackBlocked.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_check(refresh: true));
    }
  }

  void _onRecheck() {
    unawaited(_check());
  }

  Future<void> _check({bool refresh = false}) {
    final Future<void>? current = _checkInFlight;
    if (current != null) {
      _checkAgain = true;
      _refreshAgain = _refreshAgain || refresh;
      return current;
    }
    final Future<void> next = _runCheck(refresh: refresh);
    _checkInFlight = next;
    return next.whenComplete(() {
      if (identical(_checkInFlight, next)) {
        _checkInFlight = null;
      }
      if (_checkAgain && mounted) {
        final refresh = _refreshAgain;
        _checkAgain = false;
        _refreshAgain = false;
        unawaited(_check(refresh: refresh));
      }
    });
  }

  Future<void> _runCheck({required bool refresh}) async {
    if (refresh) {
      final refreshCallback = widget.refresh;
      if (refreshCallback != null) {
        try {
          await refreshCallback().timeout(widget.refreshTimeout);
        } catch (_) {
          // Evaluate active cached values when network refresh fails.
        }
      }
    }

    _EmergencyState next = _EmergencyState.none;
    try {
      final appMoved = await AppMovedService(
        remoteConfig: widget.remoteConfig,
      ).evaluate();
      if (appMoved.isRequired) {
        next = _EmergencyState(
          block: _EmergencyBlock.appMoved,
          forceUpdate: ForceUpdateStatus.notRequired,
          appMoved: appMoved,
        );
      } else {
        final forceUpdate = await ForceUpdateService(
          config: _forceUpdateConfig,
          remoteConfig: widget.remoteConfig,
          installedVersionLoader: widget.loadCurrentVersion,
        ).evaluate();
        next = _EmergencyState(
          block: forceUpdate.isRequired
              ? _EmergencyBlock.forceUpdate
              : _EmergencyBlock.none,
          forceUpdate: forceUpdate,
          appMoved: appMoved,
        );
      }
    } catch (_) {
      next = _EmergencyState.none;
    }

    if (!mounted) return;
    _playbackBlocked.value = next.block != _EmergencyBlock.none;
    setState(() => _state = next);
  }

  ForceUpdateConfig get _forceUpdateConfig {
    return ForceUpdateConfig(
      iosAppId: '6763862332',
      androidPackageName: 'com.majoon.yalla',
      backgroundColor: AppColors.primaryDark,
      textColor: AppColors.textPrimary,
      buttonColor: AppColors.textPrimary,
      buttonTextColor: AppColors.primaryDark,
    );
  }

  AppMovedConfig get _appMovedConfig {
    return const AppMovedConfig(
      backgroundColor: AppColors.primaryDark,
      textColor: AppColors.textPrimary,
      buttonColor: AppColors.textPrimary,
      buttonTextColor: AppColors.primaryDark,
    );
  }

  ForceUpdateStrings _forceUpdateStrings(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
    return locale.languageCode.toLowerCase() == 'ar'
        ? ForceUpdateStrings.arabic()
        : ForceUpdateStrings.english();
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _state.block != _EmergencyBlock.none;
    return EmergencyBlockNotice(
      blocked: _playbackBlocked,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          TickerMode(
            enabled: !blocked,
            child: Offstage(offstage: blocked, child: widget.child),
          ),
          if (_state.block == _EmergencyBlock.appMoved)
            AppMovedScreen(
              config: _appMovedConfig,
              strings: AppMovedStrings.of(context),
              status: _state.appMoved,
            )
          else if (_state.block == _EmergencyBlock.forceUpdate)
            ForceUpdateScreen(
              config: _forceUpdateConfig,
              strings: _forceUpdateStrings(context),
              status: _state.forceUpdate,
            ),
        ],
      ),
    );
  }
}
