//
//  FileManager+.swift
//  
//
//  Created by Alisa Mylnikova on 10.03.2023.
//

import Foundation

extension FileManager {

    static var tempDirPath: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    static var tempFile: URL {
        FileManager.tempDirPath.appendingPathComponent(UUID().uuidString)
    }

    static func tempAudioFile(_ wav: Bool = true) -> URL {
        FileManager.tempDirPath.appendingPathComponent(UUID().uuidString + (wav ? ".wav": ".aac"))
    }
}
