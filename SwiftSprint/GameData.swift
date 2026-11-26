//
//  GameData.swift
//  SwiftSprint
//
//  Everything that is NOT a screen lives here:
//  1. GameType      - the 4 mini-games
//  2. Question      - one round of a game
//  3. SprintResult  - one finished sprint (saved in history)
//  4. GameStore     - saves XP, levels and history (UserDefaults)
//  5. QuestionMaker - creates a new random question for a game + level
//

import UIKit

// MARK: - 1. The four mini-games

enum GameType: Int, CaseIterable {
    case oddOneOut = 0
    case patternNext = 1
    case spotError = 2
    case colorRush = 3

    var title: String {
        switch self {
        case .oddOneOut: return "Odd One Out"
        case .patternNext: return "Next in Pattern"
        case .spotError: return "Spot the Error"
        case .colorRush: return "Color Rush"
        }
    }

    var skill: String {
        switch self {
        case .oddOneOut: return "Visual matching"
        case .patternNext: return "Pattern recognition"
        case .spotError: return "Attention to detail"
        case .colorRush: return "Quick decisions"
        }
    }

    var prompt: String {
        switch self {
        case .oddOneOut: return "Tap the one that is different"
        case .patternNext: return "Which number comes next?"
        case .spotError: return "One copy has a mistake. Tap it!"
        case .colorRush: return "Tap the INK colour, not the word"
        }
    }

    var icon: String {
        switch self {
        case .oddOneOut: return "square.grid.3x3.fill"
        case .patternNext: return "chart.line.uptrend.xyaxis"
        case .spotError: return "magnifyingglass"
        case .colorRush: return "paintpalette.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .oddOneOut: return .systemOrange
        case .patternNext: return .systemBlue
        case .spotError: return .systemPurple
        case .colorRush: return .systemPink
        }
    }
}

// MARK: - 2. One question (one round)

struct Question {
    var display: String                 // big text shown on top
    var displayColor: UIColor = .label
    var options: [String]               // what the tiles show
    var optionColors: [UIColor] = []    // empty = normal text colour
    var answer: Int                     // index of the correct tile
    var columns: Int                    // tiles per row
    var squareTiles: Bool               // true = grid of squares
}

// MARK: - 3. One finished sprint

struct SprintResult: Codable {
    var game: Int
    var level: Int
    var score: Int
    var correct: Int
    var rounds: Int
    var avgTime: Double
    var xp: Int
    var unlocked: Bool
    var date: Date

    var accuracy: Int {
        return rounds == 0 ? 0 : correct * 100 / rounds
    }

    var gameType: GameType {
        return GameType(rawValue: game) ?? .oddOneOut
    }
}

// MARK: - 4. Saving progress

class GameStore {

    static let shared = GameStore()
    static let maxLevel = 6
    static let passMark = 70          // % accuracy needed to unlock next level

    let defaults = UserDefaults.standard
    let rankNames = ["Rookie", "Sprinter", "Pro", "Ace", "Champion"]
    let rankXP = [0, 200, 600, 1500, 3000]

    var playerName: String {
        get { return defaults.string(forKey: "playerName") ?? "" }
        set { defaults.set(newValue, forKey: "playerName") }
    }

    var totalXP: Int {
        get { return defaults.integer(forKey: "totalXP") }
        set { defaults.set(newValue, forKey: "totalXP") }
    }

    var darkMode: Bool {
        get { return defaults.bool(forKey: "darkMode") }
        set { defaults.set(newValue, forKey: "darkMode") }
    }

    func level(for game: GameType) -> Int {
        let saved = defaults.integer(forKey: "level\(game.rawValue)")
        return saved == 0 ? 1 : saved
    }

    func bestAccuracy(for game: GameType) -> Int {
        return defaults.integer(forKey: "best\(game.rawValue)")
    }

    var history: [SprintResult] {
        get {
            guard let data = defaults.data(forKey: "history"),
                  let list = try? JSONDecoder().decode([SprintResult].self, from: data) else {
                return []
            }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "history")
            }
        }
    }

    // Saves a finished sprint: adds XP, unlocks next level, adds to history
    func record(game: GameType, level: Int, score: Int, correct: Int, rounds: Int, avgTime: Double) -> SprintResult {
        let accuracy = rounds == 0 ? 0 : correct * 100 / rounds

        var unlocked = false
        if accuracy >= GameStore.passMark && level == self.level(for: game) && level < GameStore.maxLevel {
            defaults.set(level + 1, forKey: "level\(game.rawValue)")
            unlocked = true
        }

        if accuracy > bestAccuracy(for: game) {
            defaults.set(accuracy, forKey: "best\(game.rawValue)")
        }

        totalXP += score

        let result = SprintResult(game: game.rawValue, level: level, score: score, correct: correct,
                                  rounds: rounds, avgTime: avgTime, xp: score, unlocked: unlocked, date: Date())
        var list = history
        list.insert(result, at: 0)
        history = list
        return result
    }

    func deleteResult(at index: Int) {
        var list = history
        list.remove(at: index)
        history = list
    }

    func clearHistory() {
        history = []
    }

    // Rank from total XP: Rookie -> Sprinter -> Pro -> Ace -> Champion
    func rankIndex() -> Int {
        var index = 0
        for i in 0..<rankXP.count where totalXP >= rankXP[i] {
            index = i
        }
        return index
    }

    func rankName() -> String {
        return rankNames[rankIndex()]
    }

    // 0.0 to 1.0 progress towards the next rank
    func rankProgress() -> Float {
        let i = rankIndex()
        if i == rankXP.count - 1 { return 1 }
        return Float(totalXP - rankXP[i]) / Float(rankXP[i + 1] - rankXP[i])
    }

    func xpForNextRank() -> Int? {
        let i = rankIndex()
        if i == rankXP.count - 1 { return nil }
        return rankXP[i + 1] - totalXP
    }
}

// MARK: - 5. Making questions (harder every level)

enum QuestionMaker {

    // seconds allowed per question
    static func timeLimit(for game: GameType, level: Int, hard: Bool) -> Double {
        let base = hard ? 5.0 : 8.0
        let extra = game == .oddOneOut ? 2.0 : 0.0      // big grids need a bit more time
        return max(2.5, base + extra - Double(level - 1) * 0.6)
    }

    static func make(_ game: GameType, level: Int) -> Question {
        switch game {
        case .oddOneOut: return oddOneOut(level: level)
        case .patternNext: return patternNext(level: level)
        case .spotError: return spotError(level: level)
        case .colorRush: return colorRush(level: level)
        }
    }

    // Grid of the same symbol with one different symbol hidden inside
    static func oddOneOut(level: Int) -> Question {
        let sides = [3, 3, 4, 4, 5, 6]
        let side = sides[min(level, sides.count) - 1]

        let easy = [("🍎", "🍌"), ("🐶", "🐱"), ("⭐️", "🌙"), ("🚗", "🚲"), ("⚽️", "🏀")]
        let medium = [("😀", "😃"), ("🙂", "🙃"), ("🌕", "🌖"), ("🕐", "🕑"), ("❤️", "🧡")]
        let hard = [("O", "Q"), ("8", "B"), ("C", "G"), ("M", "N"), ("E", "F"), ("P", "R")]
        let pool = level <= 2 ? easy : (level <= 4 ? medium : hard)

        let pair = pool.randomElement()!
        let flip = Bool.random()
        let normal = flip ? pair.1 : pair.0
        let odd = flip ? pair.0 : pair.1

        let count = side * side
        let answer = Int.random(in: 0..<count)
        var options = Array(repeating: normal, count: count)
        options[answer] = odd

        return Question(display: "\(side) × \(side) grid", options: options, answer: answer,
                        columns: side, squareTiles: true)
    }

    // Number sequence, find the next number. New rules unlock with level.
    static func patternNext(level: Int) -> Question {
        let kind = Int.random(in: 0..<min(level, 5))
        var seq: [Int] = []

        switch kind {
        case 0:     // add the same number
            let start = Int.random(in: 1...10)
            let step = Int.random(in: 2...6)
            for i in 0..<5 { seq.append(start + i * step) }
        case 1:     // subtract the same number
            let start = Int.random(in: 40...60)
            let step = Int.random(in: 3...8)
            for i in 0..<5 { seq.append(start - i * step) }
        case 2:     // multiply
            var value = Int.random(in: 1...4)
            let factor = Int.random(in: 2...3)
            for _ in 0..<5 {
                seq.append(value)
                value *= factor
            }
        case 3:     // gaps grow: +1, +2, +3, +4
            var value = Int.random(in: 1...10)
            for i in 0..<5 {
                seq.append(value)
                value += i + 1
            }
        default:    // each number = sum of previous two
            var a = Int.random(in: 1...5)
            var b = Int.random(in: 2...6)
            for _ in 0..<5 {
                seq.append(a)
                let c = a + b
                a = b
                b = c
            }
        }

        let shown = seq.prefix(4).map { String($0) }.joined(separator: ",  ")
        let correct = seq[4]

        var values = [correct]
        let offsets = [-3, -2, -1, 1, 2, 3, 4, 5, 10, -10].shuffled()
        for offset in offsets where values.count < 4 {
            let value = correct + offset
            if !values.contains(value) { values.append(value) }
        }
        values.shuffle()

        return Question(display: shown + ",  ?", options: values.map { String($0) },
                        answer: values.firstIndex(of: correct) ?? 0, columns: 2, squareTiles: false)
    }

    // 4 copies of a code, one copy has one wrong character
    static func spotError(level: Int) -> Question {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let similar: [Character: Character] = ["B": "8", "8": "B", "S": "5", "5": "S", "Z": "2", "2": "Z",
                                               "E": "F", "F": "E", "P": "R", "R": "P", "M": "N", "N": "M",
                                               "V": "U", "U": "V", "C": "G", "G": "C"]
        let length = 3 + level          // level 1 = 4 characters, level 6 = 9 characters

        var code: [Character] = []
        for _ in 0..<length { code.append(letters.randomElement()!) }

        var wrong = code
        let position = Int.random(in: 0..<length)
        var newChar = letters.randomElement()!
        while newChar == code[position] { newChar = letters.randomElement()! }
        if level >= 4, let lookAlike = similar[code[position]] {
            newChar = lookAlike          // from level 4 the mistake looks similar
        }
        wrong[position] = newChar

        let original = String(code)
        let answer = Int.random(in: 0..<4)
        var options = Array(repeating: original, count: 4)
        options[answer] = String(wrong)

        return Question(display: original, options: options, answer: answer,
                        columns: length <= 6 ? 2 : 1, squareTiles: false)
    }

    // Word written in a different colour (Stroop test)
    static func colorRush(level: Int) -> Question {
        let names = ["RED", "BLUE", "GREEN", "ORANGE", "PURPLE", "PINK"]
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink]

        let word = Int.random(in: 0..<names.count)
        var ink = Int.random(in: 0..<names.count)
        while ink == word { ink = Int.random(in: 0..<names.count) }

        var picks = [ink, word]
        while picks.count < 4 {
            let r = Int.random(in: 0..<names.count)
            if !picks.contains(r) { picks.append(r) }
        }
        picks.shuffle()

        // from level 3 the answer buttons are painted in confusing colours too
        var optionColors: [UIColor] = []
        if level >= 3 {
            optionColors = picks.map { _ in colors.randomElement()! }
        }

        return Question(display: names[word], displayColor: colors[ink], options: picks.map { names[$0] },
                        optionColors: optionColors, answer: picks.firstIndex(of: ink) ?? 0,
                        columns: 2, squareTiles: false)
    }
}
