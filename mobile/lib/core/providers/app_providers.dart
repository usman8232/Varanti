import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/api_client.dart';
import '../utils/error_messages.dart';
import '../../data/models/warranty_model.dart';
import '../../data/repositories/warranty_repository.dart';
import '../../features/notifications/notification_service.dart';

// --- STORAGE & GUEST PREFERENCES ---
const String _guestStorageKey = 'varanti_guest_mode_enabled';
const _secureStorage = FlutterSecureStorage();

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
    bool? isLoading,
    String? errorMessage,
    bool? isMigrating,
  }) {
    return AuthState(
      isGuest: isGuest ?? this.isGuest,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
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
    final subscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        state = state.copyWith(
          user: session.user,
          accessToken: session.accessToken,
          isGuest: false,
        );
      } else if (!state.isGuest) {
        state = const AuthState(isGuest: false);
      }
    });
    ref.onDispose(subscription.cancel);
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
      state = state.copyWith(
        user: hasSession ? res.user : null,
        accessToken: res.session?.accessToken,
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
    try {
      await _secureStorage.delete(key: _guestStorageKey);
    } catch (_) {}
    await Supabase.instance.client.auth.signOut();
    state = const AuthState(isGuest: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

// --- API & REPOSITORY PROVIDERS ---

final apiClientProvider = Provider<ApiClient?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.isGuest || authState.accessToken == null) {
    return ApiClient();
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

class WarrantyFilterState {
  final String? query;
  final String? selectedCategory;

  const WarrantyFilterState({this.query, this.selectedCategory});

  WarrantyFilterState copyWith({
    String? query,
    bool clearQuery = false,
    String? selectedCategory,
    bool clearCategory = false,
  }) {
    return WarrantyFilterState(
      query: clearQuery ? null : (query ?? this.query),
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
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
}

final warrantyFilterProvider = NotifierProvider<WarrantyFilterNotifier, WarrantyFilterState>(() {
  return WarrantyFilterNotifier();
});

final warrantiesStreamProvider = FutureProvider<List<WarrantyModel>>((ref) async {
  final repo = ref.watch(warrantyRepositoryProvider);
  final filter = ref.watch(warrantyFilterProvider);

  return await repo.getWarranties(
    query: filter.query,
    category: filter.selectedCategory,
  );
});
