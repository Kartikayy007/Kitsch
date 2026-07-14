//
//  ForegroundCutout.swift
//  Kitsch
//

import CoreImage
import UIKit
import Vision

enum ForegroundCutout {
    static func make(from data: Data) async throws -> Data? {
        let handler = ImageRequestHandler(data)
        let request = GenerateForegroundInstanceMaskRequest()

        guard let observation = try await handler.perform(request),
              !observation.allInstances.isEmpty else {
            return nil
        }

        let maskedImage = try observation.generateMaskedImage(
            for: observation.allInstances,
            imageFrom: handler,
            croppedToInstancesExtent: true
        )
        let image = CIImage(cvPixelBuffer: maskedImage)
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage).pngData()
    }
}
