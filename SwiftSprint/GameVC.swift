//
//  GameVC.swift
//  SwiftSprint
//
//  THE GAME: question on top, answer tiles in a UICollectionView,
//  timer in a UIProgressView, instant feedback, XP for speed.
//  After the last round -> alert -> segue "toResult"
//

import UIKit

class TileCell: UICollectionViewCell {

    @IBOutlet weak var tileLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 12
        contentView.backgroundColor = .secondarySystemBackground
    }
}

class GameVC: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var roundLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var timeProgress: UIProgressView!
    @IBOutlet weak var promptLabel: UILabel!
    @IBOutlet weak var questionLabel: UILabel!
    @IBOutlet weak var feedbackLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!

    // received from GamesVC through prepare(for:sender:)
    var game: GameType = .oddOneOut
    var level = 1
    var rounds = 8
    var isHard = false

    var question: Question?
    var round = 0
    var score = 0
    var correct = 0
    var answerTimes: [Double] = []
    var timeLimit = 8.0
    var timeLeft = 8.0
    var timer: Timer?
    var showingAnswer = false     // true while green/red feedback is on screen
    var tappedIndex: Int?
    var stopped = false           // true when the screen is closed
    var result: SprintResult?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = game.title

        collectionView.dataSource = self
        collectionView.delegate = self
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
        }

        timeLimit = QuestionMaker.timeLimit(for: game, level: level, hard: isHard)
        levelLabel.text = "Level \(level)"
        promptLabel.text = game.prompt
        nextRound()
    }

    // user pressed Back in the middle of a sprint -> stop everything
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopped = true
        timer?.invalidate()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }

    @objc func nextRound() {
        if stopped { return }
        if round == rounds {
            finishSprint()
            return
        }

        round += 1
        tappedIndex = nil
        showingAnswer = false
        question = QuestionMaker.make(game, level: level)

        roundLabel.text = "Round \(round)/\(rounds)"
        scoreLabel.text = "Score: \(score)"
        feedbackLabel.text = " "
        questionLabel.text = question?.display
        questionLabel.textColor = question?.displayColor
        if game == .spotError {
            questionLabel.font = UIFont.monospacedSystemFont(ofSize: 34, weight: .bold)
        } else {
            questionLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        }
        collectionView.reloadData()

        // start the countdown
        timeLeft = timeLimit
        timeProgress.progress = 1
        timeProgress.progressTintColor = .systemGreen
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
    }

    @objc func tick() {
        timeLeft -= 0.1
        timeProgress.progress = Float(max(timeLeft, 0) / timeLimit)
        if timeLeft < timeLimit * 0.3 {
            timeProgress.progressTintColor = .systemRed
        }
        if timeLeft <= 0 {
            timer?.invalidate()
            showFeedback(isCorrect: false, text: "⏰ Time up!")
        }
    }

    // MARK: - Collection view (answer tiles)

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return question?.options.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TileCell", for: indexPath) as! TileCell
        guard let question = question else { return cell }

        cell.tileLabel.text = question.options[indexPath.item]

        if question.optionColors.isEmpty {
            cell.tileLabel.textColor = .label
        } else {
            cell.tileLabel.textColor = question.optionColors[indexPath.item]
        }

        var size: CGFloat = 20
        if question.squareTiles {
            size = question.columns >= 5 ? 22 : 32
        }
        if game == .spotError {
            cell.tileLabel.font = UIFont.monospacedSystemFont(ofSize: size, weight: .semibold)
        } else {
            cell.tileLabel.font = UIFont.systemFont(ofSize: size, weight: .semibold)
        }

        // after an answer: correct tile green, wrong tap red
        var background = UIColor.secondarySystemBackground
        if showingAnswer {
            if indexPath.item == question.answer {
                background = UIColor.systemGreen.withAlphaComponent(0.4)
            } else if indexPath.item == tappedIndex {
                background = UIColor.systemRed.withAlphaComponent(0.4)
            }
        }
        cell.contentView.backgroundColor = background
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns = CGFloat(question?.columns ?? 2)
        let spacing: CGFloat = 8
        let width = floor((collectionView.bounds.width - spacing * (columns - 1)) / columns)
        let isSquare = question?.squareTiles ?? false
        return CGSize(width: width, height: isSquare ? width : 64)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !showingAnswer, let question = question else { return }

        timer?.invalidate()
        tappedIndex = indexPath.item
        answerTimes.append(timeLimit - timeLeft)

        if indexPath.item == question.answer {
            correct += 1
            let points = 10 + level * 2 + Int(timeLeft * 2)      // faster = more XP
            score += points
            showFeedback(isCorrect: true, text: "Correct! +\(points) XP")
        } else {
            showFeedback(isCorrect: false, text: "Wrong!")
        }
    }

    func showFeedback(isCorrect: Bool, text: String) {
        showingAnswer = true
        feedbackLabel.text = text
        feedbackLabel.textColor = isCorrect ? .systemGreen : .systemRed
        scoreLabel.text = "Score: \(score)"
        collectionView.reloadData()

        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(isCorrect ? .success : .error)

        perform(#selector(nextRound), with: nil, afterDelay: 0.8)
    }

    // MARK: - End of sprint

    func finishSprint() {
        timer?.invalidate()

        var avgTime = timeLimit
        if !answerTimes.isEmpty {
            avgTime = answerTimes.reduce(0, +) / Double(answerTimes.count)
        }

        result = GameStore.shared.record(game: game, level: level, score: score, correct: correct,
                                         rounds: rounds, avgTime: avgTime)

        let alert = UIAlertController(title: "Sprint Complete!",
                                      message: "You got \(correct) of \(rounds) right.\nScore: \(score)",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "See Results", style: .default) { _ in
            self.performSegue(withIdentifier: "toResult", sender: nil)
        })
        present(alert, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? ResultVC {
            vc.result = result
        }
    }
}
