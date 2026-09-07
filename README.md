# Split It

Split It is a minimalist, one-touch iOS timing game inspired by splitting the G on a pint. Hold to drink, release to stop, and place the very top of the foam inside the target.

## Game modes

### Night Out

Build the longest split streak you can while moving through pubs, rooftops, beaches, stadiums, and other venues. The buzz meter rises throughout a run, hangovers provide partial relief, and a miss ends the night.

### Daily Five

Everyone gets the same five-pour challenge each UTC day: the same venue, target position, drinking speed, and BAC condition.

- Green: 5 points
- Yellow: 3 points
- Red: 1 point
- Outside the target: 0 points
- Maximum daily score: 25 points

Daily Five results have a dedicated daily leaderboard. Night Out streaks are tracked on daily and all-time leaderboards.

## Requirements

- Xcode with the iOS 17 SDK or newer
- iOS 17 or newer
- A Game Center-capable Apple developer configuration for live leaderboards

The app is built natively with SwiftUI, Observation, AVFoundation, and GameKit. It has no third-party dependencies.

## Running locally

1. Clone the repository.
2. Open `PintLine.xcodeproj` in Xcode.
3. Select the `PintLine` scheme and an iPhone simulator.
4. Build and run.

The Xcode target and some internal filenames retain the project's original `PintLine` name; the player-facing game is named **Split It**.
