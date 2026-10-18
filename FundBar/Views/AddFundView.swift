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
    @State private var selectedFundType = ""
    @FocusState private var isFocused: Bool

    @State private var inputMode = 0 // 0: 按份额, 1: 按金额
    @State private var buyAmountText = ""
    @State private var feeText = ""
    @State private var buyDate = Date()
    @State private var isBefore3PM = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Text("添加基金")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭添加基金")
                .help("关闭")
            }

            // 搜索(系统输入框,图标内嵌左侧,加载态内嵌右侧)
            TextField("基金代码或名称", text: $searchText)
                .font(.system(size: 13))
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    if isPureCode { addFund(code: searchText) }
                }
                .onChange(of: searchText) { _, newValue in
                    onSearchTextChanged(newValue)
                }
                .overlay(alignment: .trailing) {
                    if isAdding {
                        ProgressView()
                            .controlSize(.mini)
                            .padding(.trailing, 7)
                    }
                }

            // 搜索结果列表
            if !searchResults.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(searchResults.prefix(8).enumerated()), id: \.element.id) { idx, result in
                            resultRow(result, isLast: idx >= min(searchResults.count, 8) - 1)
                        }
                    }
                }
                .frame(maxHeight: 168)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
            }

            if isSearching && searchResults.isEmpty {
                Text("搜索中…")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // 录入信息分组卡
            VStack(alignment: .leading, spacing: 10) {
                GlassSegmented(
                    items: [("按份额录入", 0), ("按金额录入", 1)],
                    selection: $inputMode
                )

                if inputMode == 0 {
                    HStack(spacing: 10) {
                        fieldCard("份额", text: $sharesText, placeholder: "可选")
                        fieldCard("成本净值", text: $costPriceText, placeholder: "可选")
                    }
                } else {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            fieldCard("买入金额", text: $buyAmountText, placeholder: "必填")
                            fieldCard("预估手续费", text: $feeText, placeholder: "可选")
                        }
                        HStack {
                            Text("买入时间")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: $buyDate, displayedComponents: .date)
                                .labelsHidden()
                                .controlSize(.small)
                            GlassSegmented(
                                items: [("15:00 前", true), ("15:00 后", false)],
                                selection: $isBefore3PM,
                                small: true
                            )
                        }
                    }
                }
            }


            // 成功提示
            if !successMessage.isEmpty {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 错误提示
            if showError {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 0)

            // 主操作:全宽添加按钮
            Button {
                if isPureCode {
                    addFund(code: searchText)
                }
            } label: {
                Text(isAdding ? "添加中…" : "添加基金")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(!isPureCode || isAdding)
        }
        .padding(16)
        .frame(width: 384, alignment: .leading)
        .onAppear {
            isFocused = true
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    /// 搜索结果行
    private func resultRow(_ result: FundSearchResult, isLast: Bool) -> some View {
        Button {
            searchText = result.code
            selectedFundType = result.type
            searchResults = []
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text(result.code)
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.tertiary)
                        if !result.type.isEmpty {
                            Text(result.type)
                                .font(.system(size: 9.5))
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
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.leading, 10)
            }
        }
    }

    /// 分组字段卡:小标题 + 输入框(系统设置页风格)
    private func fieldCard(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                if placeholder != "必填" {
                    Text(placeholder)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
            }
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12.5).monospacedDigit())
                .onChange(of: text.wrappedValue) { _, newValue in
                    let filtered = String(newValue.filter { $0.isNumber || $0 == "." })
                    if filtered != newValue { text.wrappedValue = filtered }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var separatorColor: NSColor { .separatorColor }

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
            isSearching = false
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

        let shares = inputMode == 0 ? (Double(sharesText) ?? 0) : 0
        let costPrice = inputMode == 0 ? (Double(costPriceText) ?? 0) : 0
        
        let buyAmount = inputMode == 1 ? abs(Double(buyAmountText) ?? 0) : 0
        let fee = inputMode == 1 ? abs(Double(feeText) ?? 0) : 0

        Task {
            let success = await viewModel.addFund(code: code, shares: shares, costPrice: costPrice, fundType: selectedFundType)
            isAdding = false

            if success {
                if inputMode == 1 && buyAmount > 0 {
                    viewModel.addPendingHolding(code: code, buyAmount: buyAmount, fee: fee, buyDate: buyDate, isBefore3PM: isBefore3PM)
                }

                withAnimation(.easeInOut(duration: 0.2)) {
                    successMessage = "已添加 \(code)"
                }
                // 清空输入
                searchText = ""
                sharesText = ""
                costPriceText = ""
                buyAmountText = ""
                feeText = ""
                selectedFundType = ""
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
