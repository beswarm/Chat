//
//  Created by Alex.M on 23.06.2022.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink("Active chat example") {
                        ChatExampleView(
                            viewModel: ChatExampleViewModel(interactor: MockChatInteractor(isActive: true)),
                            title: "Active chat example"
                        )
                    }
                    
                    NavigationLink("Simple example") {
                        ChatExampleView(title: "Simple example")
                    }
                    
                    NavigationLink("Push to Talk example") {
                        PttChatExampleView(viewModel: PttChatViewModel(interactor: ModelChatInteractor(isActive: true)),
                                    title: "Simple example")
                    }
                } header: {
                    Text("Basic examples")
                }
            }
            .navigationTitle("Chat examples")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    ContentView()
}
