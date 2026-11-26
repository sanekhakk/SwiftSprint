//
//  HistoryVC.swift
//  SwiftSprint
//
//  SCORE HISTORY: UITableView of every finished sprint.
//  Tap a row -> alert with details. Swipe left -> delete.
//  "Clear" bar button -> action sheet.
//

import UIKit

class HistoryVC: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var summaryLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!

    var history: [SprintResult] = []
    let store = GameStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    func reload() {
        history = store.history
        updateSummary()
        tableView.reloadData()
    }

    func updateSummary() {
        if history.isEmpty {
            summaryLabel.text = "No sprints yet. Play a challenge and it will show up here."
        } else {
            summaryLabel.text = "\(history.count) sprints  •  \(store.totalXP) XP  •  Rank: \(store.rankName())"
        }
    }

    func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Table view

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath)
        let item = history[indexPath.row]

        cell.textLabel?.text = "\(item.gameType.title)  •  Level \(item.level)"
        cell.detailTextLabel?.text = "Score \(item.score)  •  \(item.accuracy)%  •  \(String(format: "%.1f", item.avgTime))s  •  \(dateText(item.date))"
        cell.imageView?.image = UIImage(systemName: item.gameType.icon)
        cell.imageView?.tintColor = item.gameType.color
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = history[indexPath.row]

        let details = """
        Level \(item.level)
        Score: \(item.score)
        Correct: \(item.correct) of \(item.rounds) (\(item.accuracy)%)
        Average response: \(String(format: "%.1f", item.avgTime)) s
        XP earned: \(item.xp)
        \(item.unlocked ? "Unlocked the next level 🔓" : "")
        """

        let alert = UIAlertController(title: item.gameType.title, message: details, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // swipe left to delete one row
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            store.deleteResult(at: indexPath.row)
            history.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            updateSummary()
        }
    }

    @IBAction func clearTapped(_ sender: UIBarButtonItem) {
        if history.isEmpty { return }

        let sheet = UIAlertController(title: "Clear History", message: "All saved sprints will be removed. Your XP and levels stay.", preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Clear All", style: .destructive) { _ in
            self.store.clearHistory()
            self.reload()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        sheet.popoverPresentationController?.barButtonItem = sender
        present(sheet, animated: true)
    }
}
