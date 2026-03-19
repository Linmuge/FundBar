import SwiftUI

/// 添加基金弹窗视图
struct AddFundView: View {
    @ObservedObject var viewModel: FundViewModel
    @Binding var isPresented: Bool
    @State private var fundCode = ""
    @State private var isAdding = false
    @State private var showError = false
    @State private var errorText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("添加基金")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }

            // 输入框
            HStack(spacing: 8) {
                TextField("请输入6位基金代码", text: $fundCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13).monospacedDigit())
                    .focused($isFocused)
                    .onSubmit {
                        addFund()
                    }
                    .onChange(of: fundCode) { _, newValue in
                        // 限制只能输入数字，最多6位
                        let filtered = String(newValue.filter { $0.isNumber }.prefix(6))
                        if filtered != newValue {
                            fundCode = filtered
                        }
                    }

                Button {
                    addFund()
                } label: {
                    if isAdding {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("添加")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(fundCode.count != 6 || isAdding)
            }

            // 错误提示
            if showError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(errorText)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 提示文字
            Text("示例: 110011 (易方达中小盘)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .onAppear {
            isFocused = true
        }
    }

    // MARK: - Private

    private func addFund() {
        guard fundCode.count == 6 else { return }

        isAdding = true
        showError = false

        Task {
            let success = await viewModel.addFund(code: fundCode)
            isAdding = false

            if success {
                fundCode = ""
                isPresented = false
            } else {
                errorText = viewModel.errorMessage ?? "添加失败"
                withAnimation(.easeInOut(duration: 0.2)) {
                    showError = true
                }
            }
        }
    }
}
