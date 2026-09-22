import SwiftData
import SwiftUI

/// Permet d'avertir l'utilisateur que la base n'a pas pu s'ouvrir sur le disque
/// (voir `MuscuLogApp.makeContainer`) : l'app fonctionne, mais rien n'est écrit.
private struct StorageEphemeralKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var storageIsEphemeral: Bool {
        get { self[StorageEphemeralKey.self] }
        set { self[StorageEphemeralKey.self] = newValue }
    }
}

/// Navigation principale : 4 onglets, décidés pour être utilisables d'une main
/// et sans réflexion pendant l'effort.
enum AppTab: Hashable {
    case home
    case session
    case history
    case library
}

struct RootTabView: View {

    @Environment(ActiveSessionViewModel.self) private var sessionVM
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.storageIsEphemeral) private var storageIsEphemeral

    @Query(sort: [SortDescriptor(\WorkoutSession.date, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\Routine.createdAt)])
    private var routines: [Routine]

    @State private var selection: AppTab = .home

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selection) {
                NavigationStack {
                    HomeView(selectedTab: $selection)
                }
                .tabItem {
                    Label("Accueil", systemImage: "chart.bar.xaxis")
                }
                .tag(AppTab.home)

                NavigationStack {
                    ActiveSessionView(selectedTab: $selection)
                }
                .tabItem {
                    Label("Séance", systemImage: "figure.strengthtraining.traditional")
                }
                .badge(sessionVM.session == nil ? 0 : 1)
                .tag(AppTab.session)

                NavigationStack {
                    HistoryView()
                }
                .tabItem {
                    Label("Historique", systemImage: "calendar")
                }
                .tag(AppTab.history)

                NavigationStack {
                    LibraryView()
                }
                .tabItem {
                    Label("Exercices", systemImage: "list.bullet.rectangle.portrait")
                }
                .tag(AppTab.library)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if storageIsEphemeral {
                    StorageWarningBanner()
                }
            }

            if let toast = sessionVM.toast {
                ToastView(toast: toast)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(2.6))
                        withAnimation(.snappy) { sessionVM.toast = nil }
                    }
                    .onTapGesture {
                        withAnimation(.snappy) { sessionVM.toast = nil }
                    }
            }
        }
        .animation(.snappy, value: sessionVM.toast)
        .onChange(of: scenePhase) { _, phase in
            // Le widget ne se rafraîchit que lorsque l'app passe en arrière-plan :
            // c'est exactement au moment où il redevient visible.
            guard phase != .active else { return }
            WidgetSnapshot.refresh(sessions: sessions, routines: routines)
            WidgetBridge.reload()
        }
    }
}

/// Onglet « Exercices » : bibliothèque + routines, accessibles via un
/// sélecteur segmenté pour rester dans un seul onglet.
struct LibraryView: View {

    enum Section: String, CaseIterable, Identifiable {
        case exercises = "Exercices"
        case routines = "Routines"
        var id: String { rawValue }
    }

    @State private var section: Section = .exercises

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(Section.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            switch section {
            case .exercises: ExercisesView()
            case .routines: RoutinesView()
            }
        }
        .navigationTitle(section.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}
