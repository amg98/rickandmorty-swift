import RxSwift
import RealmSwift

class RealmCharacterDetailsDataSource: CharacterDetailsLocalDataSource {
    let realmFactory: RealmFactory
    let realmQueue: DispatchQueue

    init(realmFactory: RealmFactory, realmQueue: DispatchQueue) {
        self.realmFactory = realmFactory
        self.realmQueue = realmQueue
    }

    func getObservable(id: String) -> Observable<CharacterDetails> {
        return .create { observer in
            var subscription: NotificationToken? = .none
            do {
                let realm = try self.realmFactory.buildWithoutQueue()
                subscription = realm.objects(RealmCharacterDetails.self)
                    .where { $0.summary.primaryId.equals(RealmCharacterSummary.primaryId(id: id)) }
                    .observe { changes in
                        if case .error = changes { return }
                        Task {
                            let detail = await self.getCharacterDetail(id: id)
                            guard let detail = detail else { return }

                            observer.onNext(detail)
                        }
                    }
            } catch {}

            return Disposables.create {
                subscription?.invalidate()
            }
        }
    }

    private func getCharacterDetail(id: String) async -> CharacterDetails? {
        return await realmQueue.runAsync { continuation in
            do {
                let realm = try self.realmFactory.build()
                let detail = realm.objects(RealmCharacterDetails.self)
                    .where { $0.summary.primaryId.equals(RealmCharacterSummary.primaryId(id: id)) }
                    .first
                return continuation.resume(returning: detail?.toDomain())
            } catch {
                return continuation.resume(returning: .none)
            }
        }
    }

    func upsertCharacterDetail(detail: CharacterDetails) async {
        return await realmQueue.runAsync { continuation in
            defer {
                continuation.resume(returning: ())
            }

            do {
                let realm = try self.realmFactory.build()

                try realm.write {
                    let summary = realm.objects(RealmCharacterSummary.self)
                        .where { $0.primaryId.equals(RealmCharacterSummary.primaryId(id: detail.id)) }
                        .first

                    if let summary = summary {
                        let realmDetail = self.buildCharacterDetail(detail: detail, realm: realm)
                        realm.add(realmDetail, update: .modified)
                        summary.detail = realmDetail
                    } else {
                        let summary = CharacterSummary.Builder()
                            .set(id: detail.id)
                            .set(name: detail.name)
                            .set(imageURL: detail.imageURL)
                            .set(status: detail.status)
                            .build()

                        let realmSummary = RealmCharacterSummary(character: summary)
                        let realmDetail = self.buildCharacterDetail(detail: detail, realm: realm)

                        realmSummary.detail = realmDetail
                        realm.add(realmSummary)

                        let latestFilter = realm.objects(RealmCharacterFilter.self)
                            .sorted(by: \.createdAt, ascending: false)
                            .first!

                        let list = realm.objects(RealmCharacterList.self)
                            .where { $0.filter.primaryId.equals(latestFilter.primaryId) }
                            .first! // List must exist here

                        list.uncachedCharacters.append(realmSummary)
                    }
                }
            } catch {}
        }
    }

    private func buildCharacterDetail(detail: CharacterDetails, realm: Realm) -> RealmCharacterDetails {
        let realmDetail = RealmCharacterDetails(detail: detail)

        if let origin = detail.origin {
            let oldOrigin = realm.objects(RealmLocationSummary.self).where {
                $0.primaryId.equals(RealmLocationSummary.primaryId(id: origin.id))
            }.first
            let realmOrigin = RealmLocationSummary(characterLocation: origin, type: oldOrigin?.type)
            realm.add(realmOrigin, update: .modified)
            realmDetail.origin = realmOrigin
        }

        if let location = detail.location {
            let oldLocation = realm.objects(RealmLocationSummary.self).where {
                $0.primaryId.equals(RealmLocationSummary.primaryId(id: location.id))
            }.first
            let realmLocation = RealmLocationSummary(characterLocation: location, type: oldLocation?.type)
            realm.add(realmLocation, update: .modified)
            realmDetail.location = realmLocation
        }

        let realmEpisodes = detail.episodes.map { RealmEpisodeSummary(episodeSummary: $0) }
        realmEpisodes.forEach {
            realm.add($0, update: .modified)
        }
        realmDetail.episodes.append(objectsIn: realmEpisodes)

        return realmDetail
    }

    func existsCharacterDetails(id: String) async -> Bool {
        return await realmQueue.runAsync { continuation in
            do {
                let realm = try self.realmFactory.build()
                let exists = realm.objects(RealmCharacterDetails.self)
                    .where { $0.summary.primaryId.equals(RealmCharacterSummary.primaryId(id: id)) }
                    .count > 0
                return continuation.resume(returning: exists)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
