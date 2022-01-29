//
//  PlayerControlsViewModel.swift
//  BookPlayer
//
//  Created by Pavel Kyzmin on 09.01.2022.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class PlayerControlsViewModel: BaseViewModel<PlayerControlsCoordinator> {
  let playerManager: PlayerManagerProtocol
  let speedManager: SpeedManagerProtocol
  let speedStep: Float = 0.1

  init(playerManager: PlayerManagerProtocol,
       speedManager: SpeedManagerProtocol) {
    self.playerManager = playerManager
    self.speedManager = speedManager
  }

  func currentSpeedPublisher() -> AnyPublisher<Float, Never> {
    return self.playerManager.currentSpeedPublisher()
  }

  func getMinimumSpeedValue() -> Float {
    return Float(self.speedManager.minimumSpeed)
  }

  func getMaximumSpeedValue() -> Float {
    return Float(self.speedManager.maximumSpeed)
  }

  func getCurrentSpeed() -> Float {
    return self.playerManager.getCurrentSpeed()
  }

  func getBoostVolumeFlag() -> Bool {
    return UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)
  }

  func handleBoostVolumeToggle(flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)

    self.playerManager.boostVolume = flag
  }

  func roundSpeedValue(_ value: Float) -> Float {
    return round(value / self.speedStep) * self.speedStep
  }

  func handleSpeedChange(newValue: Float) {
    let roundedValue = round(newValue * 100) / 100.0

    self.speedManager.setSpeed(
      roundedValue,
      relativePath: self.playerManager.currentItem?.relativePath
    )
  }
}