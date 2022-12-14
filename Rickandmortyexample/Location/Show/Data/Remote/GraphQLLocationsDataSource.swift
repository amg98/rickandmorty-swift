import Apollo

class GraphQLLocationsDataSource: LocationsRemoteDataSource {
    var pageSize: UInt32 = 20

    let apolloClient: ApolloClient

    init(apolloClient: ApolloClient) {
        self.apolloClient = apolloClient
    }

    func getLocations(page: UInt32, filter: LocationFilter) async -> Result<PaginatedResponse<LocationSummary>, Error> {
        let result = await apolloClient.fetchAsync(
            query: LocationsQuery(page: Int(page), filter: FilterLocation.from(filter: filter))
        )
        guard let result = result.unwrap() else {
            return .failure(Error(message: result.failure()!.localizedDescription))
        }

        guard let locations = result.data?.locations?.results else {
            return .failure(Error(message: String(localized: "error/unknown")))
        }

        guard let info = result.data?.locations?.info else {
            return .failure(Error(message: String(localized: "error/unknown")))
        }

        let domainCharacters = locations
            .compactMap { $0 }
            .map { $0.fragments.locationSummaryFragment.toDomain() }

        return .success(PaginatedResponse(items: domainCharacters, hasNext: info.next != nil))
    }
}

extension FilterLocation {

    static func from(filter: LocationFilter) -> Self {
        return FilterLocation(
            name: .from(filter.name),
            type: .from(filter.type),
            dimension: .from(filter.dimension)
        )
    }
}
