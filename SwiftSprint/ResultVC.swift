//
//  ResultVC.swift
//  SwiftSprint
//
//  RESULTS: score, accuracy, speed, XP earned, level unlock.
//  Buttons go back with the navigation controller.
//

import UIKit

class ResultVC: UIViewController {

    @IBOutlet weak var resultImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var accuracyLabel: UILabel!
    @IBOutlet weak var accuracyProgress: UIProgressView!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var xpLabel: UILabel!
    @IBOutlet weak var unlockLabel: UILabel!

    // received from GameVC through prepare(for:sender:)
    var result: SprintResult?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hidesBackButton = true      // the finished game should not be reopened

        guard let result = result else { return }
        let passed = result.accuracy >= GameStore.passMark

        resultImage.image = UIImage(systemName: passed ? "trophy.fill" : "arrow.counterclockwise.circle.fill")
        resultImage.tintColor = passed ? .systemYellow : .systemOrange
        titleLabel.text = passed ? "Great Sprint!" : "Keep Practising"

        scoreLabel.text = "Score: \(result.score)"
        accuracyLabel.text = "Accuracy: \(result.accuracy)%  (\(result.correct)/\(result.rounds) correct)"
        accuracyProgress.progress = Float(result.accuracy) / 100
        accuracyProgress.progressTintColor = passed ? .systemGreen : .systemOrange
        speedLabel.text = String(format: "Average response: %.1f s", result.avgTime)
        xpLabel.text = "+\(result.xp) XP  •  Total \(GameStore.shared.totalXP) XP"

        if result.unlocked {
            unlockLabel.text = "🔓 Level \(result.level + 1) unlocked!"
            unlockLabel.textColor = .systemGreen
        } else if result.level >= GameStore.maxLevel {
            unlockLabel.text = "You are on the top level. Beat your best!"
            unlockLabel.textColor = .label
        } else if passed {
            unlockLabel.text = "Nice! Try a harder level next."
            unlockLabel.textColor = .label
        } else {
            unlockLabel.text = "Get \(GameStore.passMark)% or more to unlock the next level"
            unlockLabel.textColor = .secondaryLabel
        }
    }

    @IBAction func playAgainTapped(_ sender: UIButton) {
        if let gamesScreen = navigationController?.viewControllers.first(where: { $0 is GamesVC }) {
            navigationController?.popToViewController(gamesScreen, animated: true)
        }
    }

    @IBAction func homeTapped(_ sender: UIButton) {
        navigationController?.popToRootViewController(animated: true)
    }
}
