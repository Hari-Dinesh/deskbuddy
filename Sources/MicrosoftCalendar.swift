import Foundation
import Security

enum MicrosoftFailure: LocalizedError {
    case message(String), rateLimited(TimeInterval), signedOut
    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        case .rateLimited: return "Microsoft is limiting requests. DeskBuddy will retry later."
        case .signedOut: return "Microsoft sign-in expired. Connect again."
        }
    }
}

struct MicrosoftTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

enum MicrosoftKeychain {
    private static let service = "io.github.hari-dinesh.deskbuddy.microsoft"
    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    static func load(account: String) throws -> MicrosoftTokens? {
        var request = query(account)
        request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw MicrosoftFailure.message("Could not read Microsoft credentials from Keychain (\(status)).") }
        return try JSONDecoder().decode(MicrosoftTokens.self, from: data)
    }
    static func save(_ tokens: MicrosoftTokens, account: String) throws {
        let data = try JSONEncoder().encode(tokens)
        let request = query(account)
        let status = SecItemUpdate(request as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw MicrosoftFailure.message("Could not update Microsoft Keychain credentials (\(status)).") }
        var item = request
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw MicrosoftFailure.message("Could not save Microsoft credentials to Keychain.") }
    }
    static func remove(account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw MicrosoftFailure.message("Could not remove Microsoft credentials from Keychain (\(status)).") }
    }
}

struct MicrosoftDeviceCode: Decodable {
    let device_code: String
    let user_code: String
    let expires_in: Int
    let interval: Int?
}

struct MicrosoftTokenResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    func tokens(previousRefreshToken: String = "") -> MicrosoftTokens {
        MicrosoftTokens(accessToken: access_token, refreshToken: refresh_token ?? previousRefreshToken, expiresAt: Date().addingTimeInterval(Double(expires_in)))
    }
}

struct MicrosoftOAuthError: Decodable { let error: String }

struct GraphCalendarPage: Decodable {
    struct Event: Decodable {
        struct Moment: Decodable { let dateTime: String; let timeZone: String }
        struct Online: Decodable { let joinUrl: String? }
        let id: String
        let subject: String?
        let start: Moment
        let end: Moment
        let isCancelled: Bool?
        let isAllDay: Bool?
        let webLink: String?
        let onlineMeeting: Online?
    }
    let value: [Event]
    let nextLink: String?
    enum CodingKeys: String, CodingKey { case value; case nextLink = "@odata.nextLink" }
    static func date(_ moment: Event.Moment) -> Date? {
        let raw = moment.dateTime
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }
        guard moment.timeZone == "UTC" || moment.timeZone == "Etc/UTC" else { return nil }
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            let parser = DateFormatter(); parser.locale = Locale(identifier: "en_US_POSIX"); parser.timeZone = TimeZone(secondsFromGMT: 0); parser.dateFormat = format
            if let date = parser.date(from: raw) { return date }
        }
        return nil
    }
    static func safeLink(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value), url.scheme == "https", url.user == nil, url.password == nil,
              let host = url.host?.lowercased(), ["teams.microsoft.com", "teams.live.com", "teams.cloud.microsoft", "outlook.office.com", "outlook.office365.com", "outlook.live.com", "outlook.cloud.microsoft"].contains(host) else { return nil }
        return url
    }
    func meetings() throws -> [CalendarMeeting] {
        try value.compactMap { event in
            guard event.isCancelled != true, event.isAllDay != true else { return nil }
            guard let start = Self.date(event.start), let end = Self.date(event.end), end > start else { throw MicrosoftFailure.message("Microsoft returned an unsupported meeting time. Cached meetings were retained.") }
            return CalendarMeeting(id: event.id, title: String((event.subject ?? "Calendar meeting").prefix(300)), start: start, end: end, joinURL: Self.safeLink(event.onlineMeeting?.joinUrl) ?? Self.safeLink(event.webLink))
        }
    }
}

struct MicrosoftCalendarClient {
    var session: URLSession = .shared
    var pollWait: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    private func endpoint(_ settings: MicrosoftSettings, _ path: String) throws -> URL {
        guard settings.valid else { throw MicrosoftFailure.message("Enter a valid Application (client) ID and tenant ID (or organizations/common).") }
        return URL(string: "https://login.microsoftonline.com/\(settings.tenant)/oauth2/v2.0/\(path)")!
    }
    static func form(_ values: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics; allowed.insert(charactersIn: "-._~")
        return values.sorted { $0.key < $1.key }.map { key, value in "\(key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\(value.addingPercentEncoding(withAllowedCharacters: allowed)!)" }.joined(separator: "&").data(using: .utf8)!
    }
    private func post(_ settings: MicrosoftSettings, path: String, values: [String: String]) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: try endpoint(settings, path)); request.httpMethod = "POST"
        request.timeoutInterval = 30; request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.form(values)
        let (data, raw) = try await session.data(for: request)
        guard let response = raw as? HTTPURLResponse else { throw MicrosoftFailure.message("Invalid Microsoft response.") }
        if response.statusCode == 429 { throw MicrosoftFailure.rateLimited(Self.retryDelay(response)) }
        return (data, response)
    }
    static func retryDelay(_ response: HTTPURLResponse) -> TimeInterval {
        min(3600, max(60, Double(response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 300))
    }
    func startSignIn(_ settings: MicrosoftSettings) async throws -> MicrosoftDeviceCode {
        let (data, response) = try await post(settings, path: "devicecode", values: ["client_id": settings.clientID, "scope": "offline_access Calendars.ReadBasic"])
        guard response.statusCode == 200 else { throw MicrosoftFailure.message("Microsoft could not start sign-in (HTTP \(response.statusCode)). Check the app registration and public-client setting.") }
        return try JSONDecoder().decode(MicrosoftDeviceCode.self, from: data)
    }
    func finishSignIn(_ settings: MicrosoftSettings, code: MicrosoftDeviceCode) async throws -> MicrosoftTokens {
        let deadline = Date().addingTimeInterval(Double(code.expires_in))
        var interval = min(30, max(5, code.interval ?? 5))
        while Date() < deadline {
            try await pollWait(UInt64(interval) * 1_000_000_000)
            try Task.checkCancellation()
            let (data, response) = try await post(settings, path: "token", values: ["client_id": settings.clientID, "device_code": code.device_code, "grant_type": "urn:ietf:params:oauth:grant-type:device_code"])
            if response.statusCode == 200 { return try JSONDecoder().decode(MicrosoftTokenResponse.self, from: data).tokens() }
            let error = try? JSONDecoder().decode(MicrosoftOAuthError.self, from: data)
            if error?.error == "authorization_pending" { continue }
            if error?.error == "slow_down" { interval += 5; continue }
            throw MicrosoftFailure.message("Microsoft sign-in was declined, expired, or blocked by your organization. Start again or ask your administrator.")
        }
        throw MicrosoftFailure.message("The sign-in code expired. Connect again for a new code.")
    }
    func refresh(_ settings: MicrosoftSettings, tokens: MicrosoftTokens) async throws -> MicrosoftTokens {
        let (data, response) = try await post(settings, path: "token", values: ["client_id": settings.clientID, "refresh_token": tokens.refreshToken, "grant_type": "refresh_token", "scope": "offline_access Calendars.ReadBasic"])
        guard response.statusCode == 200 else {
            if response.statusCode >= 500 { throw MicrosoftFailure.message("Microsoft is temporarily unavailable. Your connection is preserved.") }
            throw MicrosoftFailure.signedOut
        }
        return try JSONDecoder().decode(MicrosoftTokenResponse.self, from: data).tokens(previousRefreshToken: tokens.refreshToken)
    }
    func meetings(token: String, from start: Date, to end: Date) async throws -> [CalendarMeeting] {
        let iso = ISO8601DateFormatter()
        var query = URLComponents(string: "https://graph.microsoft.com/v1.0/me/calendarView")!
        query.queryItems = [URLQueryItem(name: "startDateTime", value: iso.string(from: start)), URLQueryItem(name: "endDateTime", value: iso.string(from: end)), URLQueryItem(name: "$select", value: "id,subject,start,end,isCancelled,isAllDay,webLink,onlineMeeting"), URLQueryItem(name: "$top", value: "100")]
        var next = query.url
        var result: [CalendarMeeting] = []
        var pages = 0
        while let url = next {
            try Task.checkCancellation()
            guard url.scheme == "https", url.host == "graph.microsoft.com", url.user == nil, url.password == nil, pages < 20 else { throw MicrosoftFailure.message("Unexpected or excessively large calendar response. Existing meetings were retained.") }
            var request = URLRequest(url: url); request.timeoutInterval = 30
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("outlook.timezone=\"UTC\", IdType=\"ImmutableId\"", forHTTPHeaderField: "Prefer")
            let (data, raw) = try await session.data(for: request)
            guard let response = raw as? HTTPURLResponse else { throw MicrosoftFailure.message("Invalid calendar response.") }
            if response.statusCode == 429 { throw MicrosoftFailure.rateLimited(Self.retryDelay(response)) }
            if response.statusCode == 401 { throw MicrosoftFailure.signedOut }
            guard response.statusCode == 200 else { throw MicrosoftFailure.message("Calendar sync failed (HTTP \(response.statusCode)). Check calendar consent and Microsoft 365 availability.") }
            let page = try JSONDecoder().decode(GraphCalendarPage.self, from: data)
            result += try page.meetings(); pages += 1
            if let link = page.nextLink {
                guard let valid = URL(string: link) else { throw MicrosoftFailure.message("Invalid calendar page link.") }
                next = valid
            } else { next = nil }
        }
        return Array(Dictionary(result.map { ($0.reminderKey, $0) }, uniquingKeysWith: { first, _ in first }).values)
    }
}
