import Foundation

final class CalendarMockProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: String], Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, headers, body) = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}

@main struct MicrosoftCalendarTests {
    static func main() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [CalendarMockProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let client = MicrosoftCalendarClient(session: session)
        let page = #"{"value":[{"id":"one","subject":"Planning","start":{"dateTime":"2026-10-21T09:30:00.0000000","timeZone":"UTC"},"end":{"dateTime":"2026-10-21T10:00:00.0000000","timeZone":"UTC"},"onlineMeeting":{"joinUrl":"https://teams.microsoft.com/l/meetup-join/example"}},{"id":"cancelled","subject":"Cancelled","isCancelled":true,"start":{"dateTime":"2026-10-21T09:00:00Z","timeZone":"UTC"},"end":{"dateTime":"2026-10-21T10:00:00Z","timeZone":"UTC"}},{"id":"all-day","isAllDay":true,"start":{"dateTime":"2026-10-21T00:00:00Z","timeZone":"UTC"},"end":{"dateTime":"2026-10-22T00:00:00Z","timeZone":"UTC"}}]}"#.data(using: .utf8)!
        CalendarMockProtocol.handler = { request in
            precondition(request.httpMethod == "GET")
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-access")
            precondition(request.value(forHTTPHeaderField: "Prefer")!.contains("UTC"))
            return (200, [:], page)
        }
        let meetings = try await client.meetings(token: "test-access", from: Date(), to: Date().addingTimeInterval(3600))
        precondition(meetings.count == 1 && meetings[0].title == "Planning" && meetings[0].joinURL?.host == "teams.microsoft.com")
        precondition(meetings[0].end.timeIntervalSince(meetings[0].start) == 1800)
        precondition(GraphCalendarPage.safeLink("file:///etc/passwd") == nil)
        precondition(GraphCalendarPage.safeLink("https://teams.microsoft.com.evil.example/join") == nil)
        precondition(GraphCalendarPage.safeLink("https://user@teams.microsoft.com/join") == nil)
        precondition(GraphCalendarPage.date(.init(dateTime: "2026-10-21T09:00:00", timeZone: "Unknown zone")) == nil)
        print("PASS UTC parsing, cancellation/all-day filtering, authorization and safe join URLs")

        var count = 0
        CalendarMockProtocol.handler = { request in
            count += 1
            if count == 1 { return (200, [:], #"{"value":[],"@odata.nextLink":"https://graph.microsoft.com/v1.0/me/calendarView?page=2"}"#.data(using: .utf8)!) }
            return (200, [:], page)
        }
        let paginated = try await client.meetings(token: "test-access", from: Date(), to: Date())
        precondition(count == 2 && paginated.count == 1)
        CalendarMockProtocol.handler = { _ in (200, [:], #"{"value":[],"@odata.nextLink":"https://other.example/steal"}"#.data(using: .utf8)!) }
        do { _ = try await client.meetings(token: "test-access", from: Date(), to: Date()); preconditionFailure("Foreign pagination must fail") } catch { }
        CalendarMockProtocol.handler = { _ in (429, ["Retry-After": "120"], Data()) }
        do { _ = try await client.meetings(token: "test-access", from: Date(), to: Date()); preconditionFailure("429 must back off") }
        catch MicrosoftFailure.rateLimited(let delay) { precondition(delay == 120) }
        CalendarMockProtocol.handler = { _ in (401, [:], Data()) }
        do { _ = try await client.meetings(token: "test-access", from: Date(), to: Date()); preconditionFailure("401 requires sign-in") }
        catch MicrosoftFailure.signedOut { }
        print("PASS pagination, foreign-page rejection, rate limits and expired authorization")

        var settings = MicrosoftSettings(); settings.clientID = "00000000-0000-4000-8000-000000000000"
        CalendarMockProtocol.handler = { request in
            precondition(request.url!.host == "login.microsoftonline.com" && request.httpMethod == "POST")
            return (200, [:], #"{"device_code":"test-device","user_code":"TEST-CODE","expires_in":900,"interval":5}"#.data(using: .utf8)!)
        }
        let device = try await client.startSignIn(settings)
        precondition(device.user_code == "TEST-CODE")
        CalendarMockProtocol.handler = { _ in (200, [:], #"{"access_token":"new-test-access","expires_in":3600}"#.data(using: .utf8)!) }
        let refreshed = try await client.refresh(settings, tokens: MicrosoftTokens(accessToken: "old-test", refreshToken: "old-refresh", expiresAt: .distantPast))
        precondition(refreshed.refreshToken == "old-refresh" && refreshed.accessToken == "new-test-access")
        let encoded = String(data: MicrosoftCalendarClient.form(["value": "a+b & c"]), encoding: .utf8)!
        precondition(encoded == "value=a%2Bb%20%26%20c")
        print("PASS device-code request, refresh-token preservation and form escaping")

        var waits: [UInt64] = []
        var polling = client
        polling.pollWait = { waits.append($0) }
        count = 0
        CalendarMockProtocol.handler = { _ in
            count += 1
            if count == 1 { return (400, [:], #"{"error":"authorization_pending"}"#.data(using: .utf8)!) }
            if count == 2 { return (400, [:], #"{"error":"slow_down"}"#.data(using: .utf8)!) }
            return (200, [:], #"{"access_token":"signed-in-test","refresh_token":"refresh-test","expires_in":3600}"#.data(using: .utf8)!)
        }
        let signedIn = try await polling.finishSignIn(settings, code: device)
        precondition(signedIn.accessToken == "signed-in-test" && waits == [5_000_000_000, 5_000_000_000, 10_000_000_000])
        let expired = MicrosoftDeviceCode(device_code: "expired", user_code: "EXPIRED", expires_in: -1, interval: 5)
        do { _ = try await polling.finishSignIn(settings, code: expired); preconditionFailure("Expired code must stop") } catch { }
        polling.pollWait = { _ in throw CancellationError() }
        do { _ = try await polling.finishSignIn(settings, code: device); preconditionFailure("Cancellation must stop polling") } catch is CancellationError { }
        print("PASS pending sign-in, slow-down interval, expired code and cancellation")
    }
}
