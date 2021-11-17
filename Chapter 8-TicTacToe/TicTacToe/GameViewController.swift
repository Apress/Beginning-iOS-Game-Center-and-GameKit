//
//  GameViewController.swift
//  TicTacToe
//
//  Created by Beau G. Bolle on 2021-9-30.
//

import UIKit
import GameKit

class GameViewController: UIViewController {

    @IBOutlet private var buttons: [UIButton]!
    @IBOutlet private var teamLabel: UILabel!
    @IBOutlet private var statusLabel: UILabel!
    @IBOutlet private var forfeitButton: UIButton!

    var match: GKTurnBasedMatch? {
        didSet {
            loadMatchData()
        }
    }
    
    private var localParticipant: GKTurnBasedParticipant? {
        match?.participants.first{ $0.player == GKLocalPlayer.local }
    }
    private var otherParticipant: GKTurnBasedParticipant? {
        guard let localParticipant = localParticipant else { return nil }

        return match?.participants.first{ $0 != localParticipant }
    }
    private var localPlayerIsCurrentParticipant: Bool {
        guard let localParticipant = localParticipant else { return false }

        return match?.currentParticipant == localParticipant
    }
    private var nextParticipant: GKTurnBasedParticipant? {
        guard let localParticipant = localParticipant else { return nil }

        return localPlayerIsCurrentParticipant ? otherParticipant : localParticipant
    }

    private enum Player: String, Codable {
        case none
        case x
        case o

        var title: String {
            switch self {
            case .none: return "unknown"
            case .x: return "❌"
            case .o: return "⭕️"
            }
        }
        var buttonTitle: String? {
            switch self {
            case .none: return nil
            case .x, .o: return title
            }
        }
    }
    private var localPlayer: Player = .none
    private var otherPlayer: Player {
        switch localPlayer {
        case .none: return .none
        case .x: return .o
        case .o: return .x
        }
    }
    private var currentPlayer: Player {
        if let currentParticipant = match?.currentParticipant, let firstParticipant = match?.participants.first {
            return currentParticipant == firstParticipant ? .x : .o
        }
        return .none
    }
    private var nextPlayer: Player {
        switch currentPlayer {
        case .x: return .o
        case .o, .none: return .x
        }
    }

    private typealias GameBoard = [Int: Player]
    private var gameBoard: GameBoard = [:] {
        didSet {
            logGameBoard("didSet")
        }
    }
    private var gameBoardData: Data? {
        logGameBoard("Serializing")
        return try? JSONEncoder().encode(gameBoard)
    }
    
    private enum GameStatus {
        case waitingForLocalPlayer
        case waitingForOtherPlayer
        case localPlayerWon
        case otherPlayerWon
        case playersTied
    }
    private var currentGameStatus: GameStatus {
        if let localParticipant = localParticipant {
            switch localParticipant.matchOutcome {
            case .none:
                break
            case .quit, .lost, .timeExpired:
                return .otherPlayerWon
            case .won, .first, .second, .third, .fourth, .customRange:
                return .localPlayerWon
            case .tied:
                return .playersTied
            @unknown default:
                print("Unknown GKTurnBasedParticipant.matchOutcome received. Assuming game is in progress.")
            }
        }

        let winningCombinations = [
            // horizontal
            [0, 1, 2],
            [3, 4, 5],
            [6, 7, 8],

            // vertical
            [0, 3, 6],
            [1, 4, 7],
            [2, 5, 8],

            // diagonal
            [0, 4, 8],
            [2, 4, 6],
        ]
        let winningCombination = winningCombinations.first { combo in
            let filledSquares: [Player] = combo.compactMap{ gameBoard[$0] }.filter{ $0 != .none}
            guard filledSquares.count == combo.count else { return false }
            let uniquePlayers = Set(filledSquares)
            return uniquePlayers.count == 1
        }
        guard let winningPlayerIndex = winningCombination?[0], let winningPlayer = gameBoard[winningPlayerIndex] else {
            guard gameBoard.count != 9 else { return .playersTied }

            return localPlayerIsCurrentParticipant ? .waitingForLocalPlayer : .waitingForOtherPlayer
        }
        return winningPlayer == localPlayer ? .localPlayerWon : .otherPlayerWon
    }
    
    private func logGameBoard(_ label: String) {
        print((["\(label):"] + gameBoard.map{ "\($0.key): \($0.value.buttonTitle ?? "")" }).joined(separator: "\n"))
    }
    private var logError: (Error?) -> Void = { error in
        guard let error = error else { return }
        print("An error occurred updating turn: \(error.localizedDescription)")
    }
        
    private func loadMatchData() {
        guard let match = match, let firstMatchParticipant = match.participants.first else {
            localPlayer = .none
            gameBoard = GameBoard()
            updateView()
            return
        }

        localPlayer = firstMatchParticipant.player == GKLocalPlayer.local ? .x : .o
        match.loadMatchData { (data, error) in
            if let error = error {
                print("Load Match Data: \(error.localizedDescription)")
                return
            }
            if self.otherParticipant?.matchOutcome == .quit, self.localParticipant?.matchOutcome != .won {
                self.endMatchInTurn(participantOutcome: .won, nextParticipantOutcome: nil)
                return
            }
            guard let data = data else { return }

            do {
                self.gameBoard = try JSONDecoder().decode(GameBoard.self, from: data)
            } catch {
                self.gameBoard = GameBoard()
            }
            self.updateView()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        GKLocalPlayer.local.register(self)
        updateView()
    }

    private func updateView() {
        teamLabel.text = "You are playing \(localPlayer.title)."

        let statusText: String
        let forfeitButtonEnabled: Bool
        switch currentGameStatus {
        case .waitingForLocalPlayer:
            statusText = "It's your turn."
            forfeitButtonEnabled = true
        case .waitingForOtherPlayer:
            statusText = "It's \(otherPlayer.title)'s turn."
            forfeitButtonEnabled = true
        case .localPlayerWon:
            statusText = "You won!"
            forfeitButtonEnabled = false
        case .otherPlayerWon:
            statusText = "You lost."
            forfeitButtonEnabled = false
        case .playersTied:
            statusText = "It's a tie."
            forfeitButtonEnabled = false
        }
        statusLabel.text = statusText
        forfeitButton.isEnabled = forfeitButtonEnabled

        for index in 0..<9 {
            let player = gameBoard[index] ?? .none
            let button = buttons[index]
            button.setTitle(player.buttonTitle, for: .normal)
            button.isEnabled = localPlayerIsCurrentParticipant && player == .none
        }
    }

    private func sendMatchData() {
        switch currentGameStatus {
        case .waitingForLocalPlayer:
            endTurn()
        case .localPlayerWon:
            endMatchInTurn(participantOutcome: .won, nextParticipantOutcome: .lost)
        case .playersTied:
            endMatchInTurn(participantOutcome: .tied, nextParticipantOutcome: .tied)
        case .waitingForOtherPlayer, .otherPlayerWon:
            break
        }
    }

    private func endTurn() {
        guard let match = match, let nextParticipant = nextParticipant, let gameBoardData = gameBoardData else { return }

        match.endTurn(withNextParticipants: [nextParticipant], turnTimeout: GKTurnTimeoutDefault, match: gameBoardData) { [weak self] error in
            self?.logError(error)
            self?.updateView()
        }
    }

    private func endMatchInTurn(participantOutcome: GKTurnBasedMatch.Outcome, nextParticipantOutcome: GKTurnBasedMatch.Outcome?) {
        guard let match = match,
              let currentParticipant = match.currentParticipant,
              let nextParticipant = nextParticipant,
              let gameBoardData = gameBoardData else { return }

        currentParticipant.matchOutcome = participantOutcome
        if let nextParticipantOutcome = nextParticipantOutcome {
            nextParticipant.matchOutcome = nextParticipantOutcome
        }
        match.endMatchInTurn(withMatch: gameBoardData) { [weak self] error in
            self?.logError(error)
            self?.loadMatchData()
        }
    }

    @IBAction private func makeMove(_ sender: UIButton) {
        guard let index = buttons.firstIndex(of: sender) else { return }
        
        gameBoard[index] = localPlayer
        sendMatchData()
    }

    @IBAction func forfeitTapped() {
        if localPlayerIsCurrentParticipant {
            endMatchInTurn(participantOutcome: .quit, nextParticipantOutcome: .won)
        } else {
            quitMatchOutOfTurn()
        }
    }
    
    private func quitMatchOutOfTurn() {
        guard let match = match else { return }
        
        match.participantQuitOutOfTurn(with: .quit) { [weak self] error in
            self?.logError(error)
            self?.loadMatchData()
        }
    }
    
}

extension GameViewController: GKLocalPlayerListener {

    func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        guard match.matchID == self.match?.matchID else { return }

        self.match = match
    }

    func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        guard match.matchID == self.match?.matchID else { return }

        self.match = match
    }

}
