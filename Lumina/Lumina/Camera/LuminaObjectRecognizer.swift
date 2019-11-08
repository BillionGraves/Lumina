//
//  LuminaObjectRecognition.swift
//  Lumina
//
//  Created by David Okun on 9/25/17.
//  Copyright © 2017 David Okun. All rights reserved.
//

import UIKit
import CoreML
import Vision

/// An object that represents a prediction about an object that Lumina detects
public struct LuminaPrediction {
    /// The name of the object, as predicted by Lumina
    public var name: String
    /// The numeric value of the confidence of the prediction, out of 1.0
    public var confidence: Float
    /// The unique identifier associated with this prediction, as determined by the Vision framework
    public var UUID: UUID
    /// The bounding box for object detection models that return VNDetectedObjectObservation
    public var bbox: CGRect?
}

/// An object that represents a collection of predictions that Lumina detects, along with their associated types
public struct LuminaRecognitionResult {
    /// The collection of predictions in a given result, as predicted by Lumina
    public var predictions: [LuminaPrediction]?
    /// The String type of MLModel that made the predictions
    public var type: String
}

@available(iOS 11.0, *)
final class LuminaObjectRecognizer: NSObject {
    private var modelPairs: [LuminaModel]

    init(modelPairs: [LuminaModel]) {
        LuminaLogger.notice(message: "initializing object recognizer", metadata: ["Model Count": "\(modelPairs.count)"])
        self.modelPairs = modelPairs
    }

    func recognize(from image: UIImage, completion: @escaping ([LuminaRecognitionResult]?) -> Void) {
        guard let coreImage = image.cgImage else {
            completion(nil)
            return
        }
        var recognitionResults = [LuminaRecognitionResult]()
        let recognitionGroup = DispatchGroup()
        for modelPair in modelPairs {
            recognitionGroup.enter()
            guard let model = modelPair.model, let modelType = modelPair.type else {
                recognitionGroup.leave()
                continue
            }
            guard let visionModel = try? VNCoreMLModel(for: model) else {
                recognitionGroup.leave()
                continue
            }
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                if error != nil || request.results == nil {
                    recognitionResults.append(LuminaRecognitionResult(predictions: nil, type: modelType))
                    recognitionGroup.leave()
                } else if let results = request.results {
                    let mappedResults = self.mapResults(results)
                    recognitionResults.append(LuminaRecognitionResult(predictions: mappedResults, type: modelType))
                    recognitionGroup.leave()
                }
            }
            let handler = VNImageRequestHandler(cgImage: coreImage)
            do {
                try handler.perform([request])
            } catch {
                recognitionGroup.leave()
            }
        }
        recognitionGroup.notify(queue: DispatchQueue.main) {
            LuminaLogger.notice(message: "object recognizer finished scanning image - returning results from models")
            completion(recognitionResults)
        }
    }

    private func mapResults(_ objects: [Any]) -> [LuminaPrediction] {
        var results = [LuminaPrediction]()
        for object in objects {
            if let object = object as? VNClassificationObservation {
                results.append(LuminaPrediction(name: object.identifier, confidence: object.confidence, UUID: object.uuid, bbox: nil))
            } else if let object = object as? VNDetectedObjectObservation {
                if #available(iOS 12, *) {
                    results.append(LuminaPrediction(name: object.label, confidence: object.confidenceScore, UUID: object.uuid, bbox: object.boundingBox))
                }
            }
        }
        return results.sorted(by: {
            $0.confidence > $1.confidence
        })
    }
}

extension LuminaPrediction {
    public func overlap(_ prediction: LuminaPrediction) -> Float {
        if let rect1 = self.bbox {
            if let rect2 = prediction.bbox {
                let x_overlap = max(0, min(rect1.maxX, rect2.maxX) - max(rect1.minX, rect2.minX));
                let y_overlap = max(0, min(rect1.maxY, rect2.maxY) - max(rect1.minY, rect2.minY));
                let overlapArea = x_overlap * y_overlap;
                return Float(overlapArea) / (Float(rect1.maxX - rect1.minX) * Float(rect1.maxY - rect1.minY))
            }
        }
        return 0
    }
    
    public func isSame(_ prediction: LuminaPrediction) -> Bool {
        let overlap = self.overlap(prediction)
        return overlap > 0.2
    }
}

@available(iOS 12.0, *)
extension VNDetectedObjectObservation {
    var label: String {
        if let observation = self as? VNRecognizedObjectObservation {
            if let label = observation.labels.first?.identifier {
                return label
            }
        }
        return "Object"
    }
}

@available(iOS 12.0, *)
extension VNDetectedObjectObservation {
    var confidenceScore: Float {
        if let observation = self as? VNRecognizedObjectObservation {
            if let confidence = observation.labels.first?.confidence {
                return confidence
            }
        }
        return 0
    }
}

