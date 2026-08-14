import Foundation

private let baselineOptions: [String: Any] = [
    "call": "ChordRecognizer().notesToChord(midiNoteValues: notes)"
]

private func toneDocument(_ tone: Tone) -> [String: Any] {
    return [
        "degree": ["rawValue": tone.degree.rawValue, "name": tone.degree.toString()],
        "signs": tone.signs.map { sign in
            ["rawValue": sign.rawValue, "name": sign.toString()]
        },
    ]
}

private func chordDocument(_ chord: Chord) -> [String: Any] {
    var result: [String: Any] = [
        "rootNote": Int(chord.rootNote),
        "rootPitchClass": Int(chord.rootNote % 12),
        "quality": [
            "rawValue": chord.quality.rawValue,
            "name": chord.quality.toString(),
        ],
        "factorQuality": [
            "rawValue": chord.factorQuality.rawValue,
            "name": chord.factorQuality.toString(),
        ],
        "factors": chord.factors.map(toneDocument),
        "additions": chord.additions.map(toneDocument),
        "alteredNotes": chord.alteredNotes.map(toneDocument),
        "notes": chord.notes.map(Int.init),
        "invertedNotes": chord.invertedNotes.map(Int.init),
        "inversion": chord.inversion.rawValue,
        "fullName": chord.getFullName(),
        "rootName": chord.getRootName(),
    ]
    if let omission = chord.ommission {
        result["omission"] = [
            "rawValue": omission.rawValue,
            "name": omission.toString(),
        ]
    } else {
        result["omission"] = NSNull()
    }
    return result
}

private func groupDocument(_ group: ChordGroup) -> [String: Any] {
    return [
        "fullName": group.getFullName(),
        "isPolyChord": group.isPolyChord(),
        "score": group.getScore(),
        "notes": group.notes.map(Int.init),
        "chords": group.chords.map(chordDocument),
    ]
}

private func response(_ request: [String: Any]) -> [String: Any] {
    let requestID = request["id"] as? String ?? ""
    do {
        if request["injectException"] as? Bool == true {
            throw NSError(
                domain: "WhatChordBaselineControl",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "injected adapter exception"]
            )
        }
        guard
            let observation = request["observation"] as? [String: Any],
            let midiValues = observation["orderedMidiNotes"] as? [Int]
        else {
            throw NSError(
                domain: "WhatChordBaselineInput",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "invalid neutral observation"]
            )
        }
        guard midiValues.allSatisfy({ 0...127 ~= $0 }) else {
            throw NSError(
                domain: "WhatChordBaselineInput",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "MIDI note outside 0...127"]
            )
        }
        let adapterInput = midiValues.map(UInt8.init)
        let groups = ChordRecognizer().notesToChord(midiNoteValues: adapterInput)
        return [
            "id": requestID,
            "adapterInput": adapterInput.map(Int.init),
            "options": baselineOptions,
            "rawReturn": groups.map(groupDocument),
            "nativeStdout": "",
            "nativeStderr": "",
            "status": groups.isEmpty ? "no-output" : "ok",
        ]
    } catch {
        return [
            "id": requestID,
            "adapterInput": NSNull(),
            "options": baselineOptions,
            "rawReturn": [
                "exceptionType": String(reflecting: type(of: error)),
                "message": error.localizedDescription,
            ],
            "nativeStdout": "",
            "nativeStderr": "",
            "status": "exception",
        ]
    }
}

while let line = readLine() {
    if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        continue
    }
    do {
        let data = Data(line.utf8)
        guard let request = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw NSError(
                domain: "WhatChordBaselineInput",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "request must be a JSON object"]
            )
        }
        let output = try JSONSerialization.data(
            withJSONObject: response(request),
            options: [.sortedKeys]
        )
        print(String(decoding: output, as: UTF8.self))
    } catch {
        let fallback: [String: Any] = [
            "id": "",
            "adapterInput": NSNull(),
            "options": baselineOptions,
            "rawReturn": [
                "exceptionType": String(reflecting: type(of: error)),
                "message": error.localizedDescription,
            ],
            "nativeStdout": "",
            "nativeStderr": "",
            "status": "exception",
        ]
        let output = try! JSONSerialization.data(
            withJSONObject: fallback,
            options: [.sortedKeys]
        )
        print(String(decoding: output, as: UTF8.self))
    }
}
