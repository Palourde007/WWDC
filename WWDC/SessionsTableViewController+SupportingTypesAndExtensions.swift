//
//  SessionsTableViewController+SupportingTypesAndExtensions.swift
//  WWDC
//
//  Created by Allen Humphreys on 6/6/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import ConfCore
import RealmSwift
import Combine
import OSLog

/// Conforming to this protocol means the type is capable
/// of uniquely identifying a `Session`
///
/// TODO: Move to ConfCore and make it "official"?
protocol SessionIdentifiable {
    var sessionIdentifier: String { get }
}

struct SessionIdentifier: SessionIdentifiable, Hashable {
    let sessionIdentifier: String

    init(_ string: String) {
        sessionIdentifier = string
    }
}

extension SessionViewModel: SessionIdentifiable {
    var sessionIdentifier: String {
        return identifier
    }
}

protocol SessionsTableViewControllerDelegate: AnyObject {

    func sessionTableViewContextMenuActionWatch(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionUnWatch(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionFavorite(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionRemoveFavorite(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionDownload(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionCancelDownload(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionRevealInFinder(viewModels: [SessionViewModel])
}

extension Session {

    var isWatched: Bool {
        if let progress = progresses.first {
            return progress.relativePosition > Constants.watchedVideoRelativePosition
        }

        return false
    }
}

extension Array where Element == SessionRow {

    func index(of session: SessionIdentifiable) -> Int? {
        return firstIndex { row in
            guard case .session(let viewModel) = row.kind else { return false }

            return viewModel.identifier == session.sessionIdentifier
        }
    }

    func firstSessionRowIndex() -> Int? {
        return firstIndex { row in
            if case .session = row.kind {
                return true
            }
            return false
        }
    }

    func forEachSessionViewModel(_ body: (SessionViewModel) throws -> Void) rethrows {
        try forEach {
            if case .session(let viewModel) = $0.kind {
                try body(viewModel)
            }
        }
    }
}

final class FilterResults: Logging {
    static let log = makeLogger()

    static var empty: FilterResults {
        return FilterResults(storage: nil, query: nil)
    }

    private let query: NSPredicate?

    private let storage: Storage?

    private(set) var latestSearchResults: Results<Session>?

    private lazy var cancellables: Set<AnyCancellable> = []
    private var nowPlayingBag: Set<AnyCancellable> = []

    private var observerClosure: ((Results<Session>?) -> Void)?
    private var observerToken: NotificationToken?

    init(storage: Storage?, query: NSPredicate?) {
        self.storage = storage
        self.query = query

        if let coordinator = (NSApplication.shared.delegate as? AppDelegate)?.coordinator {

            coordinator
                .$playerOwnerSessionIdentifier
                .sink(receiveValue: { [weak self] _ in
                    self?.bindResults()
                })
                .store(in: &nowPlayingBag)
        }
    }

    func observe(with closure: @escaping (Results<Session>?) -> Void) {
        assert(observerClosure == nil)

        guard query != nil, storage != nil else {
            closure(nil)
            return
        }

        observerClosure = closure

        bindResults()
    }

    private func bindResults() {
        guard let observerClosure = observerClosure else { return }
        guard let storage = storage, let query = query?.orCurrentlyPlayingSession() else { return }

        cancellables = []

        do {
            let realm = try Realm(configuration: storage.realmConfig)

            let objects = realm.objects(Session.self).filter(query)

            // Immediately provide the first value
            self.latestSearchResults = objects
            observerClosure(objects)

            objects
                .collectionChangedPublisher
                .dropFirst(1) // first value is provided synchronously to help with timing issues
                .replaceErrorWithEmpty()
                .sink { [weak self] in
                    self?.latestSearchResults = $0
                    observerClosure($0)
                }
                .store(in: &cancellables)
        } catch {
            observerClosure(nil)
            log.error("Failed to initialize Realm for searching: \(String(describing: error), privacy: .public)")
        }
    }
}

fileprivate extension NSPredicate {

    func orCurrentlyPlayingSession() -> NSPredicate {

        guard let playingSession = (NSApplication.shared.delegate as? AppDelegate)?.coordinator?.playerOwnerSessionIdentifier else {
            return self
        }

        return NSCompoundPredicate(orPredicateWithSubpredicates: [self, NSPredicate(format: "identifier == %@", playingSession)])
    }
}
