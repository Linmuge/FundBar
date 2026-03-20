import SwiftUI

/// 添加基金弹窗视图（含搜索）
struct AddFundView: View {
    @ObservedObject var viewModel: FundViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var sharesText = ""
    @State private var costPriceText = ""
    @State private var isAdding = false
    @State private var showError = false
    @State private var errorText = ""
    @State private var successMessage = ""
    @State private var searchResults: [FundSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
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

            // 搜索输入
            HStack(spacing: 8) {
                TextField("输入基金代码或名称搜索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .focused($isFocused)
                    .onSubmit {
                        if isPureCode { addFund(code: searchText) }
                    }
                    .onChange(of: searchText) { _, newValue in
                        onSearchTextChanged(newValue)
                    }

                Button {
                    if isPureCode {
                        addFund(code: searchText)
                    }
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
                .disabled(!isPureCode || isAdding)
            }

            // 搜索结果列表
            if !searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(searchResults.prefix(8)) { result in
                            Button {
                                searchText = result.code
                                searchResults = []
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        HStack(spacing: 4) {
                                            Text(result.code)
                                                .font(.system(size: 10).monospacedDigit())
                                                .foregroundStyle(.secondary)
                                            if !result.type.isEmpty {
                                                Text(result.type)
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    if viewModel.watchedCodes.contains(result.code) {
                                        Text("已添加")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if result.id != searchResults.prefix(8).last?.id {
                                Divider().padding(.leading, 8)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            }

            if isSearching {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("搜索中...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // 持仓信息（可选）
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("份额")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    TextField("可选", text: $sharesText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12).monospacedDigit())
                        .onChange(of: sharesText) { _, newValue in
                            let filtered = String(newValue.filter { $0.isNumber || $0 == "." })
                            if filtered != newValue { sharesText = filtered }
                        }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("成本净值")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    TextField("可选", text: $costPriceText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12).monospacedDigit())
                        .onChange(of: costPriceText) { _, newValue in
                            let filtered = String(newValue.filter { $0.isNumber || $0 == "." })
                            if filtered != newValue { costPriceText = filtered }
                        }
                }
            }

            // 成功提示
            if !successMessage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text(successMessage)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
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
        }
        .padding(16)
        .onAppear {
            isFocused = true
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    // MARK: - Private

    private var isPureCode: Bool {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count == 6 && text.allSatisfy { $0.isNumber }
    }

    private func onSearchTextChanged(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        // 纯6位代码不搜索
        if isPureCode {
            searchResults = []
            return
        }

        isSearching = true
        searchTask = Task {
            // 防抖 300ms
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            let results = await FundService.shared.searchFunds(keyword: trimmed)
            guard !Task.isCancelled else { return }

            isSearching = false
            searchResults = results
        }
    }

    private func addFund(code: String) {
        guard isPureCode else { return }

        isAdding = true
        showError = false
        successMessage = ""

        let shares = Double(sharesText) ?? 0
        let costPrice = Double(costPriceText) ?? 0

        Task {
            let success = await viewModel.addFund(code: code, shares: shares, costPrice: costPrice)
            isAdding = false

            if success {
                withAnimation(.easeInOut(duration: 0.2)) {
                    successMessage = "已添加 \(code)"
                }
                // 清空输入
                searchText = ""
                sharesText = ""
                costPriceText = ""
                searchResults = []
                isFocused = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        successMessage = ""
                    }
                }
            } else {
                errorText = viewModel.errorMessage ?? "添加失败"
                withAnimation(.easeInOut(duration: 0.2)) {
                    showError = true
                }
            }
        }
    }
}
