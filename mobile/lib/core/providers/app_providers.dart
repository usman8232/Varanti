import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../utils/error_messages.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/warranty_model.dart';
import '../../data/repositories/warranty_repository.dart';
import '../../features/notifications/notification_service.dart';

// --- STORAGE & PREFERENCES ---
const String _guestStorageKey = 'varanti_guest_mode_enabled';
const String _themeModeStorageKey = 'varanti_theme_mode';
const _secureStorage = FlutterSecureStorage();

Future<ThemeMode> loadSavedThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_themeModeStorageKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  } catch (_) {
    return ThemeMode.system;
  }
}

final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_themeModeStorageKey, value);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

/// Provider for initial guest state loaded synchronously/pre-boot in main()
final initialGuestProvider = Provider<bool>((ref) => false);

/// Provider for initial notification settings loaded pre-boot in main()
final initialNotificationSettingsProvider = Provider<NotificationSettings>(
  (ref) => const NotificationSettings(),
);

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() => ref.read(initialNotificationSettingsProvider);

  Future<void> updateSettings(NotificationSettings next) async {
    state = next;
    await next.save();
    try {
      final repo = ref.read(warrantyRepositoryProvider);
      final warranties = await repo.getWarranties();
      await NotificationService.instance.syncAllWarranties(warranties, next);
    } catch (_) {}
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(() {
  return NotificationSettingsNotifier();
});

// --- AUTH STATE & NOTIFIER (Riverpod 3.x) ---

class AuthState {
  final bool isGuest;
  final User? user;
  final String? accessToken;
  final bool isLoading;
  final String? errorMessage;
  final bool isMigrating;

  const AuthState({
    this.isGuest = false,
    this.user,
    this.accessToken,
    this.isLoading = false,
    this.errorMessage,
    this.isMigrating = false,
  });

  bool get isAuthenticated => user != null && accessToken != null;

  AuthState copyWith({
    bool? isGuest,
    User? user,
    String? accessToken,
    bool clearSession = false,
    bool? isLoading,
    String? errorMessage,
    bool? isMigrating,
  }) {
    return AuthState(
      isGuest: isGuest ?? this.isGuest,
      user: clearSession ? null : (user ?? this.user),
      accessToken: clearSession ? null : (accessToken ?? this.accessToken),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isMigrating: isMigrating ?? this.isMigrating,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _init();
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return AuthState(
        user: session.user,
        accessToken: session.accessToken,
        isGuest: false,
      );
    }
    final initialGuest = ref.read(initialGuestProvider);
    return AuthState(isGuest: initialGuest);
  }

  void _init() {
    final subscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        final wasSignedOut = !state.isAuthenticated;
        try {
          await _secureStorage.delete(key: _guestStorageKey);
        } catch (_) {}
        state = state.copyWith(
          user: session.user,
          accessToken: session.accessToken,
          isGuest: false,
          isLoading: false,
        );
        if (wasSignedOut && data.event == AuthChangeEvent.signedIn) {
          await autoMigrateGuestWarranties();
        }
      } else if (!state.isGuest) {
        state = const AuthState(isGuest: false);
      }
    });
    ref.onDispose(subscription.cancel);
  }

  Future<void> signInWithOAuthProvider(OAuthProvider provider) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : AppConfig.oauthRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const ApiException("Couldn't open the sign-in page. Please try again.");
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.friendly(e),
      );
      rethrow;
    }
  }

  Future<void> sendPhoneOtp(String phone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final normalized = phone.trim().replaceAll(RegExp(r'[\s\-()]'), '');
      await Supabase.instance.client.auth.signInWithOtp(phone: normalized);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.friendly(e),
      );
      rethrow;
    }
  }

  Future<void> verifyPhoneOtp(String phone, String code) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final normalized = phone.trim().replaceAll(RegExp(r'[\s\-()]'), '');
      final res = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.sms,
        phone: normalized,
        token: code.trim(),
      );
      if (res.session == null) {
        throw const ApiException('Could not verify that code. Please try again.');
      }
      try {
        await _secureStorage.delete(key: _guestStorageKey);
      } catch (_) {}
      state = state.copyWith(
        user: res.user,
        accessToken: res.session?.accessToken,
        isGuest: false,
        isLoading: false,
      );
      await autoMigrateGuestWarranties();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.friendly(e),
      );
      rethrow;
    }
  }

  Future<void> enterGuestMode() async {
    state = const AuthState(isGuest: true);
    try {
      await _secureStorage.write(key: _guestStorageKey, value: 'true');
    } catch (_) {}
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      try {
        await _secureStorage.delete(key: _guestStorageKey);
      } catch (_) {}
      state = state.copyWith(
        user: res.user,
        accessToken: res.session?.accessToken,
        isGuest: false,
        isLoading: false,
      );
      // Auto-migrate offline SQLite records to Supabase Cloud
      await autoMigrateGuestWarranties();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: ErrorMessages.friendly(e));
      rethrow;
    }
  }

  Future<bool> signUpWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      final hasSession = res.session != null;
      if (hasSession) {
        try {
          await _secureStorage.delete(key: _guestStorageKey);
        } catch (_) {}
      }
      state = hasSession
          ? state.copyWith(
              user: res.user,
              accessToken: res.session?.accessToken,
              isGuest: false,
              isLoading: false,
            )
          : state.copyWith(
              clearSession: true,
              isGuest: false,
              isLoading: false,
            );
      // Auto-migrate offline SQLite records to Supabase Cloud if signed in immediately
      if (hasSession) {
        await autoMigrateGuestWarranties();
      }
      return hasSession;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: ErrorMessages.friendly(e));
      rethrow;
    }
  }

  Future<int> autoMigrateGuestWarranties() async {
    if (state.accessToken == null) return 0;
    state = state.copyWith(isMigrating: true);
    try {
      final repo = ref.read(warrantyRepositoryProvider);
      final migratedCount = await repo.migrateGuestWarrantiesToCloud();
      if (migratedCount > 0) {
        ref.invalidate(warrantiesStreamProvider);
      }
      return migratedCount;
    } catch (_) {
      return 0;
    } finally {
      state = state.copyWith(isMigrating: false);
    }
  }

  Future<void> signOut() async {
    final wasAuthenticated = state.isAuthenticated;
    try {
      await _secureStorage.delete(key: _guestStorageKey);
    } catch (_) {}
    if (wasAuthenticated) {
      await NotificationService.instance.cancelAll();
    }
    await Supabase.instance.client.auth.signOut();
    state = const AuthState(isGuest: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

// --- USER PROFILE PROVIDER (synced across Supabase Auth, FastAPI & local guest prefs) ---

const String _localAvatarPathKey = 'varanti_local_avatar_path';
const String _localDisplayNameKey = 'varanti_local_display_name';

final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final authState = ref.watch(authProvider);
  final apiClient = ref.watch(apiClientProvider);

  String? localAvatar;
  String? localName;
  try {
    final prefs = await SharedPreferences.getInstance();
    localAvatar = prefs.getString(_localAvatarPathKey);
    localName = prefs.getString(_localDisplayNameKey);
  } catch (_) {}

  if (authState.isGuest || authState.user == null) {
    return UserProfile(
      id: 'guest',
      fullName: (localName != null && localName.isNotEmpty) ? localName : 'Guest',
      avatarUrl: localAvatar,
    );
  }

  final user = authState.user!;
  final meta = user.userMetadata ?? const <String, dynamic>{};
  final metaName = (meta['full_name'] ?? meta['name'])?.toString();
  final metaAvatar = (meta['avatar_url'] ?? meta['picture'])?.toString();
  final baseProfile = UserProfile(
    id: user.id,
    email: user.email ?? '',
    fullName: metaName ?? localName,
    phone: user.phone ?? meta['phone']?.toString(),
    avatarUrl: metaAvatar ?? localAvatar,
  );

  if (apiClient != null) {
    try {
      final remote = await apiClient.getProfile();
      return UserProfile(
        id: remote.id.isNotEmpty ? remote.id : baseProfile.id,
        email: remote.email.isNotEmpty ? remote.email : baseProfile.email,
        fullName: remote.fullName ?? baseProfile.fullName,
        phone: remote.phone ?? baseProfile.phone,
        avatarUrl: remote.avatarUrl ?? baseProfile.avatarUrl,
        avatarPath: remote.avatarPath,
      );
    } catch (_) {
      // Fall back cleanly to Supabase Auth session metadata if backend is offline
    }
  }
  return baseProfile;
});

Future<void> saveLocalProfileCache({String? displayName, String? avatarPath}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (displayName != null) {
      await prefs.setString(_localDisplayNameKey, displayName.trim());
    }
    if (avatarPath != null) {
      await prefs.setString(_localAvatarPathKey, avatarPath);
    }
  } catch (_) {}
}

// --- API & REPOSITORY PROVIDERS ---

final apiClientProvider = Provider<ApiClient?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.isGuest || authState.accessToken == null) {
    return null;
  }
  return ApiClient(accessToken: authState.accessToken);
});

final warrantyRepositoryProvider = Provider<WarrantyRepository>((ref) {
  final authState = ref.watch(authProvider);
  final apiClient = ref.watch(apiClientProvider);

  return WarrantyRepository(
    isGuest: authState.isGuest,
    apiClient: apiClient,
  );
});

// --- WARRANTY LIST FILTER & NOTIFIER (Riverpod 3.x) ---

enum WarrantySortOrder { expiringSoonest, newest, highestValue }

class WarrantyFilterState {
  final String? query;
  final String? selectedCategory;
  final String? selectedStatus;
  final WarrantySortOrder sortOrder;

  const WarrantyFilterState({
    this.query,
    this.selectedCategory,
    this.selectedStatus,
    this.sortOrder = WarrantySortOrder.expiringSoonest,
  });

  WarrantyFilterState copyWith({
    String? query,
    bool clearQuery = false,
    String? selectedCategory,
    bool clearCategory = false,
    String? selectedStatus,
    bool clearStatus = false,
    WarrantySortOrder? sortOrder,
  }) {
    return WarrantyFilterState(
      query: clearQuery ? null : (query ?? this.query),
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedStatus:
          clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class WarrantyFilterNotifier extends Notifier<WarrantyFilterState> {
  @override
  WarrantyFilterState build() => const WarrantyFilterState();

  void updateQuery(String? query) {
    if (query == null || query.isEmpty) {
      state = state.copyWith(clearQuery: true);
    } else {
      state = state.copyWith(query: query);
    }
  }

  void updateCategory(String? category) {
    if (category == null || category.isEmpty) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  void updateStatus(String? status) {
    if (status == null || status.isEmpty) {
      state = state.copyWith(clearStatus: true);
    } else {
      state = state.copyWith(selectedStatus: status);
    }
  }

  void updateSortOrder(WarrantySortOrder order) {
    state = state.copyWith(sortOrder: order);
  }

  void clearAll() {
    state = const WarrantyFilterState();
  }
}

final warrantyFilterProvider =
    NotifierProvider<WarrantyFilterNotifier, WarrantyFilterState>(() {
  return WarrantyFilterNotifier();
});

/// Source-of-truth full warranty inventory (powers Home visual graphs,
/// notification sync, and instant client-side Vault filtering).
final warrantiesStreamProvider = FutureProvider<List<WarrantyModel>>((ref) async {
  final repo = ref.watch(warrantyRepositoryProvider);
  return await repo.getWarranties();
});

/// Instant filtered & sorted view for the Vault (Search & Archive) screen.
final filteredWarrantiesProvider =
    Provider<AsyncValue<List<WarrantyModel>>>((ref) {
  final allAsync = ref.watch(warrantiesStreamProvider);
  final filter = ref.watch(warrantyFilterProvider);

  return allAsync.whenData((items) {
    final needle = filter.query?.trim().toLowerCase() ?? '';
    final filtered = items.where((w) {
      if (filter.selectedCategory != null &&
          w.category != filter.selectedCategory) {
        return false;
      }
      if (filter.selectedStatus != null && w.status != filter.selectedStatus) {
        return false;
      }
      if (needle.isNotEmpty) {
        final matchName = w.itemName.toLowerCase().contains(needle);
        final matchMerchant =
            (w.merchantName ?? '').toLowerCase().contains(needle);
        final matchSerial =
            (w.serialNumber ?? '').toLowerCase().contains(needle);
        final matchNotes = (w.notes ?? '').toLowerCase().contains(needle);
        if (!matchName && !matchMerchant && !matchSerial && !matchNotes) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (filter.sortOrder) {
      case WarrantySortOrder.expiringSoonest:
        filtered.sort(
          (a, b) => a.warrantyExpirationDate.compareTo(b.warrantyExpirationDate),
        );
      case WarrantySortOrder.newest:
        filtered.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
      case WarrantySortOrder.highestValue:
        filtered.sort(
          (a, b) => (b.pricePaid ?? -1).compareTo(a.pricePaid ?? -1),
        );
    }

    return filtered;
  });
});
