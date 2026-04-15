import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
            StreamingView()
                .tabItem {
                    Label("Streaming", systemImage: "text.word.spacing")
                }
            StructuredOutputView()
                .tabItem {
                    Label("Structured Output", systemImage: "list.bullet.rectangle")
                }
            ToolCallingView()
                .tabItem {
                    Label("Tool Calling", systemImage: "wrench.and.screwdriver")
                }
        }
    }
}
