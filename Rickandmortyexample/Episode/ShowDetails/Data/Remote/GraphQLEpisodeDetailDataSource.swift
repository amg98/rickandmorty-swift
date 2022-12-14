class GraphQLEpisodeDetailDataSource: EpisodeDetailRemoteDataSource {
    let apolloClient: ApolloClient

    init(apolloClient: ApolloClient) {
        self.apolloClient = apolloClient
    }

    func getEpisodeDetail(id: String) async -> Result<EpisodeDetail, Error> {
        let result = await apolloClient.fetchAsync(query: EpisodeDetailQuery(id: id))
        guard let result = result.unwrap() else {
            return .failure(
                Error(message: result.failure()!.localizedDescription)
            )
        }

        guard let episode = result.data?.episode else {
            return .failure(Error(message: String(localized: "error/unknown")))
        }

        return .success(episode.toDomain())
    }
}

extension EpisodeDetailQuery.Data.Episode {
    func toDomain() -> EpisodeDetail {
        let summary = fragments.episodeSummaryFragment.toDomain()
        return EpisodeDetail.Builder()
            .set(id: summary.id)
            .set(seasonID: summary.seasonId)
            .set(name: summary.name)
            .set(date: summary.date)
            .set(characters: characters.compactMap { $0 }.map { $0.fragments.characterSummaryFragment.toDomain() })
            .build()
    }
}
