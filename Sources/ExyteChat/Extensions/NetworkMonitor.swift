//
//  NetworkMonitor.swift
//  
//
//  Created by Alisa Mylnikova on 01.09.2023.
//

import Foundation
import Network

class NetworkMonitor: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let workerQueue = DispatchQueue(label: "Monitor")
    var isConnected = false

    init(_ needCheck: Bool = true) {
        if needCheck {
            networkMonitor.pathUpdateHandler = { path in
                self.isConnected = path.status == .satisfied
                Task {
                    await MainActor.run {
                        self.objectWillChange.send()
                    }
                }
            }
            networkMonitor.start(queue: workerQueue)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10) ) {
                self.isConnected = true
            }
        }
    }
}
