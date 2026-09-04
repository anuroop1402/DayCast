import Foundation

nonisolated enum CityMapper {
    static func map(_ dto: CityDTO) -> City {
        City(
            id: dto.id,
            name: dto.name,
            // Absent for a handful of minor entries. Empty reads better in the UI than
            // "Unknown", and the region below usually disambiguates anyway.
            country: dto.country ?? "",
            admin1: dto.admin1,
            latitude: dto.latitude,
            longitude: dto.longitude,
            timezone: dto.timezone
        )
    }
}
