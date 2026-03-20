import SwiftUI

@main
struct FundBarApp: App {
    @StateObject private var viewModel = FundViewModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView(viewModel: viewModel)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                if !viewModel.funds.isEmpty, !viewModel.menuBarText.isEmpty {
                    Text(viewModel.menuBarText)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(viewModel.menuBarColor)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
