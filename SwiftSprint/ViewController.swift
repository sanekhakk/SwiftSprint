//
//  ViewController.swift
//  SwiftSprint
//
//  HOME screen: name, XP / rank, settings (slider, segment, switch)
//  Segues: "toGames" (collection view) and "toHistory" (table view)
//

import UIKit

class ViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var logoImage: UIImageView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var xpLabel: UILabel!
    @IBOutlet weak var rankProgress: UIProgressView!
    @IBOutlet weak var nextRankLabel: UILabel!
    @IBOutlet weak var roundsLabel: UILabel!
    @IBOutlet weak var roundsSlider: UISlider!
    @IBOutlet weak var modeSegment: UISegmentedControl!
    @IBOutlet weak var themeSwitch: UISwitch!

    let store = GameStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        logoImage.image = UIImage(systemName: "bolt.circle.fill")
        logoImage.tintColor = .systemOrange

        nameTextField.delegate = self
        nameTextField.text = store.playerName

        roundsLabel.text = "Rounds per sprint: \(Int(roundsSlider.value))"

        themeSwitch.isOn = store.darkMode
        navigationController?.overrideUserInterfaceStyle = store.darkMode ? .dark : .light
    }

    // runs every time we come back to Home (XP may have changed)
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshStats()
    }

    func refreshStats() {
        let name = store.playerName.isEmpty ? "Player" : store.playerName
        xpLabel.text = "\(name)  •  \(store.rankName())  •  \(store.totalXP) XP"
        rankProgress.progress = store.rankProgress()

        if let needed = store.xpForNextRank() {
            nextRankLabel.text = "\(needed) XP to next rank"
        } else {
            nextRankLabel.text = "Top rank reached!"
        }
    }

    // keyboard "return" key closes the keyboard
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    @IBAction func roundsChanged(_ sender: UISlider) {
        sender.value = sender.value.rounded()
        roundsLabel.text = "Rounds per sprint: \(Int(sender.value))"
    }

    @IBAction func themeToggle(_ sender: UISwitch) {
        navigationController?.overrideUserInterfaceStyle = sender.isOn ? .dark : .light
        store.darkMode = sender.isOn
    }

    @IBAction func startTapped(_ sender: UIButton) {
        store.playerName = nameTextField.text ?? ""
        view.endEditing(true)
        refreshStats()
        performSegue(withIdentifier: "toGames", sender: nil)
    }

    @IBAction func historyTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "toHistory", sender: nil)
    }

    @IBAction func resetTapped(_ sender: UIButton) {
        let sheet = UIAlertController(title: "Reset Progress", message: "XP, levels and history will be deleted.", preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Reset Everything", style: .destructive) { _ in
            for game in GameType.allCases {
                self.store.defaults.removeObject(forKey: "level\(game.rawValue)")
                self.store.defaults.removeObject(forKey: "best\(game.rawValue)")
            }
            self.store.totalXP = 0
            self.store.clearHistory()
            self.refreshStats()

            let alert = UIAlertController(title: "Done", message: "Progress reset. Start fresh!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        })

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = sender
        present(sheet, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? GamesVC {
            vc.rounds = Int(roundsSlider.value)
            vc.isHard = modeSegment.selectedSegmentIndex == 1
        }
    }
}
