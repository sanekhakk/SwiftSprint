//
//  GamesVC.swift
//  SwiftSprint
//
//  CHOOSE A CHALLENGE: UICollectionView with one card per mini-game.
//  Tap a card -> action sheet to pick a level -> segue "toGame"
//

import UIKit

class GameCell: UICollectionViewCell {

    @IBOutlet weak var iconImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var skillLabel: UILabel!
    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var levelProgress: UIProgressView!

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 16
        contentView.backgroundColor = .secondarySystemBackground
    }
}

class GamesVC: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!

    // received from Home through prepare(for:sender:)
    var rounds = 8
    var isHard = false

    let games = GameType.allCases
    let store = GameStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero      // use sizeForItemAt below
        }
    }

    // levels may change after a sprint, so reload every time
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return games.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GameCell", for: indexPath) as! GameCell
        let game = games[indexPath.item]
        let level = store.level(for: game)

        cell.iconImage.image = UIImage(systemName: game.icon)
        cell.iconImage.tintColor = game.color
        cell.nameLabel.text = game.title
        cell.skillLabel.text = game.skill
        cell.levelLabel.text = "Level \(level)/\(GameStore.maxLevel)  •  Best \(store.bestAccuracy(for: game))%"
        cell.levelProgress.progress = Float(level) / Float(GameStore.maxLevel)
        cell.levelProgress.progressTintColor = game.color
        return cell
    }

    // 2 cards per row
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 16 * 3) / 2
        return CGSize(width: width, height: 200)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let game = games[indexPath.item]
        let unlocked = store.level(for: game)

        let sheet = UIAlertController(title: game.title, message: game.prompt + "\nPick a level", preferredStyle: .actionSheet)

        for level in stride(from: unlocked, through: 1, by: -1) {
            let title = level == unlocked ? "Level \(level)  (latest)" : "Level \(level)"
            sheet.addAction(UIAlertAction(title: title, style: .default) { _ in
                self.performSegue(withIdentifier: "toGame", sender: [game.rawValue, level])
            })
        }

        if unlocked < GameStore.maxLevel {
            sheet.message = game.prompt + "\nScore \(GameStore.passMark)%+ on Level \(unlocked) to unlock Level \(unlocked + 1)"
        }

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = collectionView.cellForItem(at: indexPath)
        present(sheet, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? GameVC, let info = sender as? [Int] {
            vc.game = GameType(rawValue: info[0]) ?? .oddOneOut
            vc.level = info[1]
            vc.rounds = rounds
            vc.isHard = isHard
        }
    }
}
