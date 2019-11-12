//
//  File.swift
//
//
//  Created by Casey Moncur on 11/8/19.
//


import UIKit
import AVFoundation

extension LuminaViewController {
    @objc func startRecordingVideoFrames(url: URL) throws {
        if isRecordingFrames || assetWriter != nil {
            return
        }
        
        isRecordingFrames = true
        
        try assetWriter = AVAssetWriter(outputURL: url, fileType: .mp4)
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: self.camera?.videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mp4))
        videoInput!.expectsMediaDataInRealTime = true
        
        if assetWriter!.canAdd(videoInput!) {
            assetWriter?.add(videoInput!)
        }
    }
    
    @objc func stopRecordingVideoFrames(onSaved: @escaping (_ status: AVAssetWriter.Status, _ file: URL) -> Void) {
        assetWriter?.finishWriting {
            onSaved(self.assetWriter!.status, self.assetWriter!.outputURL)
            self.assetWriter = nil
            self.isRecordingFrames = false
        }
        
    }
    
}
