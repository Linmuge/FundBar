import SwiftUI

@main
struct FundBarApp: App {

    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image(systemName: "chart.line.uptrend.xyaxis")
        }
        .menuBarExtraStyle(.window)
    }
}
