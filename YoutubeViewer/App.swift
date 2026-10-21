import SwiftUI
import WebKit

@main
struct YoutubeViewerApp: App {
    @StateObject private var library = VideoLibrary()
    var body: some Scene {
        WindowGroup { MainView().environmentObject(library) }
    }
}

struct Video: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var channel: String
    var thumbnail: URL? { URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg") }
}

@MainActor final class VideoLibrary: ObservableObject {
    @Published var favorites: [Video] = [] { didSet { save() } }
    @Published var apiKey: String = "" { didSet { UserDefaults.standard.set(apiKey, forKey: "apiKey") } }
    init() {
        apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        if let data = UserDefaults.standard.data(forKey: "favorites"),
           let items = try? JSONDecoder().decode([Video].self, from: data) { favorites = items }
    }
    func contains(_ v: Video) -> Bool { favorites.contains { $0.id == v.id } }
    func toggle(_ v: Video) {
        if let idx = favorites.firstIndex(where: { $0.id == v.id }) { favorites.remove(at: idx) }
        else { favorites.insert(v, at: 0) }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(favorites) { UserDefaults.standard.set(data, forKey: "favorites") }
    }
}

enum VideoID {
    static func parse(_ text: String) -> String? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if valid(raw) { return raw }
        guard let url = URL(string: raw),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host?.lowercased() else { return nil }
        let path = url.pathComponents.filter { $0 != "/" }
        var id: String?
        if ["youtu.be", "www.youtu.be"].contains(host) { id = path.first }
        else if ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"].contains(host) {
            if path.first == "watch" {
                id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value
            } else if ["shorts", "live", "embed"].contains(path.first ?? ""), path.count > 1 {
                id = path[1]
            }
        }
        return id.flatMap { valid($0) ? $0 : nil }
    }
    private static func valid(_ s: String) -> Bool {
        s.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil
    }
}

struct MainView: View {
    @State private var selected: Video?
    var body: some View {
        TabView {
            NavigationStack { OpenView(play: { selected = $0 }).navigationTitle("YouTube Viewer") }
                .tabItem { Label("Xem", systemImage: "play.rectangle.fill") }
            NavigationStack { SearchView(play: { selected = $0 }).navigationTitle("Tìm kiếm") }
                .tabItem { Label("Tìm", systemImage: "magnifyingglass") }
            NavigationStack { SavedView(play: { selected = $0 }).navigationTitle("Thư viện") }
                .tabItem { Label("Đã lưu", systemImage: "bookmark.fill") }
            NavigationStack { SettingsView().navigationTitle("Cài đặt") }
                .tabItem { Label("Cài đặt", systemImage: "gearshape") }
        }
        .tint(.red)
        .sheet(item: $selected) { PlayerView(video: $0) }
    }
}

struct OpenView: View {
    let play: (Video) -> Void
    @State private var link = ""
    @State private var invalid = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill").font(.system(size: 48)).foregroundStyle(.red)
                    VStack(alignment: .leading) {
                        Text("Xem YouTube").font(.title2.bold())
                        Text("Phát video trực tiếp trên iPhone").foregroundStyle(.secondary)
                    }
                }.padding(.top)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Dán liên kết video").font(.headline)
                    TextField("https://youtu.be/...", text: $link)
                        .keyboardType(.URL).textInputAutocapitalization(.never)
                        .autocorrectionDisabled().textFieldStyle(.roundedBorder)
                        .onSubmit(open)
                    Button(action: open) {
                        Label("Phát video", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).tint(.red)
                }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                Text("Hỗ trợ YouTube, youtu.be, Shorts, Live và mã video.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }
        .alert("Liên kết không hợp lệ", isPresented: $invalid) {
            Button("OK", role: .cancel) {}
        } message: { Text("Vui lòng nhập đường dẫn video YouTube hợp lệ.") }
    }
    private func open() {
        guard let id = VideoID.parse(link) else { invalid = true; return }
        play(Video(id: id, title: "Video YouTube", channel: "YouTube"))
    }
}

struct VideoRow: View {
    let video: Video
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: video.thumbnail) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.gray.opacity(0.2))
                    .overlay(Image(systemName: "play.rectangle"))
            }
            .frame(width: 116, height: 66).clipped().cornerRadius(8)
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title).font(.subheadline.bold()).lineLimit(2)
                Text(video.channel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

struct SavedView: View {
    @EnvironmentObject private var library: VideoLibrary
    let play: (Video) -> Void
    var body: some View {
        Group {
            if library.favorites.isEmpty {
                ContentUnavailableView("Chưa có video", systemImage: "bookmark",
                    description: Text("Nhấn Lưu video khi đang xem để thêm vào thư viện."))
            } else {
                List {
                    ForEach(library.favorites) { video in
                        Button { play(video) } label: { VideoRow(video: video) }
                            .buttonStyle(.plain)
                    }.onDelete { library.favorites.remove(atOffsets: $0) }
                }
            }
        }
    }
}

struct APIResponse: Decodable {
    struct Item: Decodable {
        struct Identifier: Decodable { let videoId: String? }
        struct Details: Decodable { let title: String; let channelTitle: String }
        let id: Identifier
        let snippet: Details
    }
    let items: [Item]
}

struct SearchView: View {
    @EnvironmentObject private var library: VideoLibrary
    let play: (Video) -> Void
    @State private var query = ""
    @State private var videos: [Video] = []
    @State private var busy = false
    @State private var errorMessage: String?
    var body: some View {
        Group {
            if library.apiKey.isEmpty {
                ContentUnavailableView("Cần API Key", systemImage: "key",
                    description: Text("Cấu hình YouTube Data API v3 trong tab Cài đặt để tìm kiếm. Tab Xem không cần API Key."))
            } else {
                VStack(spacing: 0) {
                    HStack {
                        TextField("Tìm video...", text: $query)
                            .textFieldStyle(.roundedBorder).submitLabel(.search)
                            .onSubmit { Task { await search() } }
                        Button("Tìm") { Task { await search() } }.disabled(busy || query.isEmpty)
                    }.padding()
                    if busy { ProgressView().padding() }
                    if let errorMessage { Text(errorMessage).font(.footnote).padding() }
                    List(videos) { video in
                        Button { play(video) } label: { VideoRow(video: video) }
                            .buttonStyle(.plain)
                    }.listStyle(.plain)
                }
            }
        }
    }
    private func search() async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        busy = true
        errorMessage = nil
        defer { busy = false }
        var url = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        url.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "25"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: library.apiKey)
        ]
        guard let endpoint = url.url else { errorMessage = "URL không hợp lệ."; return }
        do {
            let (data, response) = try await URLSession.shared.data(from: endpoint)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                errorMessage = "YouTube API không cho phép tìm kiếm. Kiểm tra API key và quota."
                videos = []
                return
            }
            let result = try JSONDecoder().decode(APIResponse.self, from: data)
            videos = result.items.compactMap {
                guard let id = $0.id.videoId else { return nil }
                return Video(id: id, title: $0.snippet.title, channel: $0.snippet.channelTitle)
            }
            if videos.isEmpty { errorMessage = "Không tìm thấy video." }
        } catch {
            errorMessage = error.localizedDescription
            videos = []
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var library: VideoLibrary
    var body: some View {
        Form {
            Section("YouTube Data API v3") {
                SecureField("Nhập API Key", text: $library.apiKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            } footer: {
                Text("API Key chỉ cần cho chức năng tìm kiếm. Hạn chế quota và quyền truy cập trước khi phát hành.")
            }
            Section("Thông tin") {
                LabeledContent("Phiên bản", value: "1.0")
                Link("YouTube Terms", destination: URL(string: "https://www.youtube.com/t/terms")!)
            }
        }
    }
}

struct PlayerView: View {
    let video: Video
    @EnvironmentObject private var library: VideoLibrary
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                EmbeddedPlayer(id: video.id).aspectRatio(16 / 9, contentMode: .fit)
                    .background(.black)
                Text(video.title).font(.title3.bold()).padding(.horizontal)
                Text(video.channel).foregroundStyle(.secondary).padding(.horizontal)
                HStack {
                    Button {
                        library.toggle(video)
                    } label: {
                        Label(library.contains(video) ? "Đã lưu" : "Lưu video",
                            systemImage: library.contains(video) ? "bookmark.fill" : "bookmark")
                    }
                    ShareLink(item: URL(string: "https://www.youtube.com/watch?v=\(video.id)")!) {
                        Label("Chia sẻ", systemImage: "square.and.arrow.up")
                    }
                }.buttonStyle(.bordered).padding(.horizontal)
                Spacer()
            }
            .navigationTitle("Đang phát").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Đóng") { dismiss() }
            }}
        }
    }
}

struct EmbeddedPlayer: UIViewRepresentable {
    let id: String
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.scrollView.isScrollEnabled = false
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.currentID != id else { return }
        context.coordinator.currentID = id
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>html,body{margin:0;height:100%;background:black;overflow:hidden}
        iframe{width:100%;height:100%;border:0}</style></head>
        <body><iframe src="https://www.youtube-nocookie.com/embed/\(id)?playsinline=1"
        allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture"
        referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe></body></html>
        """
        view.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var currentID: String? }
}
