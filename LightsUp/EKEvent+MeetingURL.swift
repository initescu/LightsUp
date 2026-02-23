//
//  EKEvent+MeetingURL.swift
//  LightsUp
//

import EventKit
import Foundation

extension EKEvent {
    var meetingURL: URL? {
        if let url = self.url {
            return url
        }
        
        let meetingPatterns = [
            "zoom.us",
            "meet.google.com",
            "teams.microsoft.com",
            "webex.com",
            "gotomeeting.com",
            "whereby.com",
            "meet.jit.si"
        ]
        
        if let location = self.location {
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector?.matches(in: location, range: NSRange(location.startIndex..., in: location))
            
            for match in matches ?? [] {
                if let range = Range(match.range, in: location),
                   let url = URL(string: String(location[range])) {
                    if meetingPatterns.contains(where: { url.absoluteString.contains($0) }) {
                        return url
                    }
                }
            }
        }
        
        if let notes = self.notes {
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector?.matches(in: notes, range: NSRange(notes.startIndex..., in: notes))
            
            for match in matches ?? [] {
                if let range = Range(match.range, in: notes),
                   let url = URL(string: String(notes[range])) {
                    if meetingPatterns.contains(where: { url.absoluteString.contains($0) }) {
                        return url
                    }
                }
            }
        }
        
        return nil
    }
}
