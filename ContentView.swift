//
//  ContentView.swift
//  iOS Calculator Project
//
//  Created by Gabriel Ritter on 1/30/24.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = CalculatorViewModel()
    @State private var isDarkMode: Bool = false
    @State private var selectedTheme: ThemeOption = .classic
    @State private var accentColor: Color = .orange

    var body: some View {
        VStack(spacing: 16) {
            header

            Spacer()

            display

            if let error = viewModel.errorMessage {
                Text(LocalizedStringKey(error))
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation { viewModel.clearError() }
                    }
                    .accessibilityHint("Tap to dismiss the error and start fresh")
            }

            buttonGrid
        }
        .padding()
        .background(backgroundColor)
        .accentColor(accentColor)
        .environment(.colorScheme, isDarkMode ? .dark : .light)
        .onChange(of: selectedTheme) { newValue in
            accentColor = newValue.accentColor
        }
    }

    private var header: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 12) {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(ThemeOption.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Theme presets")
                .accessibilityHint("Choose a visual style")

                ColorPicker("Accent", selection: $accentColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Accent color picker")
            }

            HStack {
                Button(action: { withAnimation { isDarkMode.toggle() } }) {
                    Image(systemName: isDarkMode ? "sun.max" : "moon")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(isDarkMode ? .white : .black)
                        .padding(8)
                }
                .accessibilityLabel(isDarkMode ? "Disable dark mode" : "Enable dark mode")
                .accessibilityHint("Toggles the calculator appearance")

                Spacer()

                Button(action: { viewModel.isShowingHistory.toggle() }) {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .labelStyle(.titleAndIcon)
                }
                .padding(.horizontal)
                .accessibilityHint("Opens your recent calculations")
            }
        }
    }

    private var display: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(viewModel.equationText)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .accessibilityLabel("Equation")
                .accessibilityHint("Shows the full expression")

            Text(viewModel.displayText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundColor(isDarkMode ? .white : .black)
                .accessibilityLabel("Display")
                .accessibilityHint("Shows the current number or result")

            if let memoryValue = viewModel.memoryValue {
                Text("M: \(viewModel.formattedNumber(memoryValue))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Memory value \(viewModel.formattedNumber(memoryValue))")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    private var buttonGrid: some View {
        GeometryReader { proxy in
            let columns = Array(repeating: GridItem(.flexible(minimum: 64, maximum: proxy.size.width / 4)), count: 4)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(CalculatorButton.allButtons, id: \.self) { button in
                    CalculatorButtonView(
                        button: button,
                        onTap: { viewModel.handle(button) },
                        onLongPress: { longPressButton in
                            viewModel.handleLongPress(for: longPressButton)
                        }
                    )
                    .frame(height: max(64, proxy.size.height / 8))
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingHistory) {
            HistoryView(
                history: viewModel.history,
                onSelect: { entry in
                    viewModel.useHistoryEntry(entry)
                    viewModel.isShowingHistory = false
                },
                onDelete: { indexSet in
                    viewModel.deleteHistory(at: indexSet)
                },
                onPinToggle: { entry in
                    viewModel.togglePin(for: entry)
                }
            )
        }
    }

    private var backgroundColor: Color {
        isDarkMode ? .black : .white
    }
}

// MARK: - View Model

final class CalculatorViewModel: ObservableObject {
    @Published private(set) var displayText: String = "0"
    @Published private(set) var equationText: String = ""
    @Published private(set) var history: [HistoryEntry] = []
    @Published var errorMessage: String?
    @Published var isShowingHistory: Bool = false
    @Published var memoryValue: Double?

    private var currentInput: String = ""
    private var tokens: [ExpressionToken] = []
    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        return formatter
    }()

    init() {
        loadHistory()
    }

    func handle(_ button: CalculatorButton) {
        provideHapticFeedback()
        errorMessage = nil

        switch button {
        case .digit(let value):
            handleDigit(value)
        case .dot:
            handleDot()
        case .op(let op):
            handleOperator(op)
        case .equal:
            calculateResult()
        case .clear:
            clearCalculator()
        case .history:
            isShowingHistory.toggle()
        case .toggleSign:
            toggleSign()
        case .percent:
            applyPercent()
        case .backspace:
            backspace()
        case .parenthesis(let side):
            handleParenthesis(isLeft: side == .left)
        case .function(let fn):
            handleFunction(fn)
        case .memory(let action):
            handleMemory(action)
        }

        updateEquationText()
        updateDisplay()
    }

    func useHistoryEntry(_ entry: HistoryEntry) {
        currentInput = formattedNumber(entry.result)
        tokens = [.number(entry.result)]
        updateEquationText()
        updateDisplay()
    }

    func deleteHistory(at indexSet: IndexSet) {
        history.remove(atOffsets: indexSet)
        saveHistory()
    }

    func togglePin(for entry: HistoryEntry) {
        if let index = history.firstIndex(of: entry) {
            history[index].isPinned.toggle()
            history.sort { lhs, rhs in
                if lhs.isPinned == rhs.isPinned { return lhs.timestamp > rhs.timestamp }
                return lhs.isPinned && !rhs.isPinned
            }
            saveHistory()
        }
    }

    // MARK: - Input Handlers

    private func handleDigit(_ digit: Int) {
        currentInput.append(String(digit))
    }

    private func handleDot() {
        if !currentInput.contains(".") {
            if currentInput.isEmpty { currentInput = "0" }
            currentInput.append(".")
        }
    }

    private func handleOperator(_ operatorType: OperatorType) {
        guard commitCurrentInput() || (!tokens.isEmpty && currentInput.isEmpty) else {
            errorMessage = "Enter a number before selecting an operator."
            provideHapticFeedback(isError: true)
            return
        }

        if let last = tokens.last, case .operator = last { tokens.removeLast() }
        tokens.append(.operator(operatorType))
    }

    private func calculateResult() {
        guard commitCurrentInput() || (!tokens.isEmpty && currentInput.isEmpty) else {
            errorMessage = "Complete the expression before calculating."
            provideHapticFeedback(isError: true)
            return
        }

        guard tokens.containsNumber else {
            errorMessage = "Enter a number to calculate."
            return
        }

        switch evaluateTokens(tokens) {
        case .success(let value):
            let formatted = formattedNumber(value)
            displayText = formatted
            let expressionString = equationText
            let entry = HistoryEntry(expression: expressionString, result: value, timestamp: Date())
            history.insert(entry, at: 0)
            saveHistory()
            tokens = [.number(value)]
            currentInput = ""
        case .failure(let error):
            errorMessage = error
        }
    }

    private func clearCalculator() {
        currentInput = ""
        tokens = []
        errorMessage = nil
    }

    private func toggleSign() {
        if currentInput.isEmpty, let lastNumber = tokens.lastNumber {
            currentInput = formattedNumber(-lastNumber)
            tokens.removeLast()
        } else if let value = Double(currentInput) {
            currentInput = formattedNumber(-value)
        }
    }

    private func applyPercent() {
        if currentInput.isEmpty, let lastNumber = tokens.lastNumber {
            currentInput = formattedNumber(lastNumber / 100)
            tokens.removeLast()
        } else if let value = Double(currentInput) {
            currentInput = formattedNumber(value / 100)
        }
    }

    private func backspace() {
        guard !currentInput.isEmpty else { return }
        currentInput.removeLast()
        if currentInput.isEmpty { currentInput = "" }
    }

    private func handleParenthesis(isLeft: Bool) {
        if isLeft {
            tokens.append(.parenthesis(.left))
        } else {
            let openCount = tokens.filter { if case .parenthesis(.left) = $0 { return true } else { return false } }.count
            let closeCount = tokens.filter { if case .parenthesis(.right) = $0 { return true } else { return false } }.count
            guard openCount > closeCount else {
                errorMessage = "No matching '(' found."
                provideHapticFeedback(isError: true)
                return
            }
            guard commitCurrentInput() || (!tokens.isEmpty && currentInput.isEmpty) else {
                errorMessage = "Add a number before closing the parenthesis."
                return
            }
            tokens.append(.parenthesis(.right))
        }
    }

    private func handleFunction(_ function: FunctionType) {
        let value: Double?
        if !currentInput.isEmpty, let current = Double(currentInput) {
            value = current
        } else {
            value = tokens.lastNumber
            if value != nil { tokens.removeLast() }
        }

        guard let operand = value else {
            errorMessage = "Enter a number before applying a function."
            provideHapticFeedback(isError: true)
            return
        }

        let result: Double?
        switch function {
        case .sin: result = sin(operand)
        case .cos: result = cos(operand)
        case .tan: result = tan(operand)
        case .sqrt: result = operand >= 0 ? sqrt(operand) : nil
        case .square: result = pow(operand, 2)
        case .reciprocal: result = operand != 0 ? 1 / operand : nil
        }

        guard let valueResult = result else {
            errorMessage = "Invalid input for \(function.title)."
            provideHapticFeedback(isError: true)
            return
        }

        currentInput = formattedNumber(valueResult)
    }

    private func handleMemory(_ action: MemoryAction) {
        switch action {
        case .mc:
            memoryValue = nil
        case .mr:
            if let memoryValue {
                currentInput = formattedNumber(memoryValue)
            }
        case .mPlus:
            let value = Double(currentInput) ?? tokens.lastNumber ?? 0
            memoryValue = (memoryValue ?? 0) + value
        case .mMinus:
            let value = Double(currentInput) ?? tokens.lastNumber ?? 0
            memoryValue = (memoryValue ?? 0) - value
        }
    }

    func handleLongPress(for button: CalculatorButton) {
        switch button {
        case .backspace:
            clearCalculator()
        case .percent:
            if let current = Double(currentInput) {
                currentInput = formattedNumber(current * 0.15)
            }
        default:
            break
        }
        updateDisplay()
    }

    func clearError() {
        errorMessage = nil
        clearCalculator()
    }

    // MARK: - Helpers

    @discardableResult
    private func commitCurrentInput() -> Bool {
        guard !currentInput.isEmpty else { return false }
        guard let value = Double(currentInput) else {
            errorMessage = "Invalid number format."
            return false
        }

        tokens.append(.number(value))
        currentInput = ""
        return true
    }

    private func updateDisplay() {
        if !currentInput.isEmpty {
            displayText = currentInput
        } else if let lastNumber = tokens.lastNumber {
            displayText = formattedNumber(lastNumber)
        } else {
            displayText = "0"
        }
    }

    private func updateEquationText() {
        var parts: [String] = tokens.map { token in
            switch token {
            case .number(let value):
                return formattedNumber(value)
            case .operator(let op):
                return op.rawValue
            case .parenthesis(let side):
                return side == .left ? "(" : ")"
            }
        }

        if !currentInput.isEmpty { parts.append(currentInput) }
        equationText = parts.joined(separator: " ")
    }

    private func evaluateTokens(_ tokens: [ExpressionToken]) -> Result<Double, String> {
        var balance = 0
        var components: [String] = []

        for token in tokens {
            switch token {
            case .number(let value):
                components.append(String(value))
            case .operator(let op):
                components.append(op.expressionSymbol)
            case .parenthesis(let side):
                if side == .left { balance += 1 } else { balance -= 1 }
                if balance < 0 { return .failure("Unbalanced parentheses.") }
                components.append(side == .left ? "(" : ")")
            }
        }

        guard balance == 0 else { return .failure("Unbalanced parentheses.") }
        if let first = tokens.first, case .operator = first { return .failure("Expression cannot start with an operator.") }
        if let last = tokens.last, case .operator = last { return .failure("Expression cannot end with an operator.") }

        let expressionString = components.joined(separator: " ")
        let expression = NSExpression(format: expressionString)
        if let value = expression.expressionValue(with: nil, context: nil) as? NSNumber {
            if value.doubleValue.isInfinite || value.doubleValue.isNaN {
                return .failure("Result is not a number.")
            }
            return .success(value.doubleValue)
        }
        return .failure("Unable to evaluate expression.")
    }

    func formattedNumber(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func provideHapticFeedback(isError: Bool = false) {
        let generator = UIImpactFeedbackGenerator(style: isError ? .heavy : .light)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Persistence

    private func saveHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(history) {
            UserDefaults.standard.set(data, forKey: "calculatorHistory")
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "calculatorHistory") else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let saved = try? decoder.decode([HistoryEntry].self, from: data) {
            history = saved
        }
    }
}

// MARK: - Supporting Types

struct HistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID = UUID()
    let expression: String
    let result: Double
    let timestamp: Date
    var isPinned: Bool = false

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

struct CalculatorButtonView: View {
    let button: CalculatorButton
    let onTap: (CalculatorButton) -> Void
    var onLongPress: ((CalculatorButton) -> Void)?

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: { onTap(button) }) {
            Text(button.title)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .frame(minWidth: 64, maxWidth: .infinity, minHeight: 64, maxHeight: .infinity)
                .padding(.vertical, 8)
                .background(buttonBackgroundColor)
                .cornerRadius(10)
                .foregroundColor(colorScheme == .dark ? .white : .primary)
                .minimumScaleFactor(0.8)
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.35) {
            onLongPress?(button)
        }
        .accessibilityLabel(button.accessibilityLabel)
        .accessibilityHint(button.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    private var buttonBackgroundColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.2)
    }
}

struct HistoryView: View {
    @Environment(\.presentationMode) var presentationMode
    var history: [HistoryEntry]
    var onSelect: (HistoryEntry) -> Void
    var onDelete: (IndexSet) -> Void
    var onPinToggle: (HistoryEntry) -> Void

    @State private var searchText: String = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredHistory) { entry in
                    Button(action: { onSelect(entry) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.expression)
                                .font(.body)
                            Text("= \(entry.resultFormatted)")
                                .font(.headline)
                            Text(entry.formattedTimestamp)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Past calculation")
                    .accessibilityHint("Tap to reuse this result")
                    .swipeActions(edge: .trailing) {
                        Button(entry.isPinned ? "Unpin" : "Pin") {
                            onPinToggle(entry)
                        }
                        .tint(.orange)
                    }
                }
                .onDelete(perform: onDelete)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationBarTitle("History", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .accessibilityLabel("Close history")
            .accessibilityHint("Dismisses the history list"))
        }
    }

    private var filteredHistory: [HistoryEntry] {
        if searchText.isEmpty {
            return history.sorted { lhs, rhs in
                if lhs.isPinned == rhs.isPinned { return lhs.timestamp > rhs.timestamp }
                return lhs.isPinned && !rhs.isPinned
            }
        }

        return history.filter { entry in
            entry.expression.localizedCaseInsensitiveContains(searchText) ||
            entry.resultFormatted.localizedCaseInsensitiveContains(searchText)
        }
        .sorted { lhs, rhs in
            if lhs.isPinned == rhs.isPinned { return lhs.timestamp > rhs.timestamp }
            return lhs.isPinned && !rhs.isPinned
        }
    }
}

enum CalculatorButton: Hashable {
    case digit(Int)
    case dot
    case op(OperatorType)
    case equal
    case clear
    case history
    case toggleSign
    case percent
    case backspace
    case parenthesis(ParenthesisSide)
    case function(FunctionType)
    case memory(MemoryAction)

    static let allButtons: [CalculatorButton] = [
        .clear, .toggleSign, .percent, .backspace,
        .memory(.mc), .memory(.mr), .memory(.mPlus), .memory(.mMinus),
        .function(.square), .function(.sqrt), .function(.reciprocal), .op(.divide),
        .digit(7), .digit(8), .digit(9), .op(.multiply),
        .digit(4), .digit(5), .digit(6), .op(.subtract),
        .digit(1), .digit(2), .digit(3), .op(.add),
        .digit(0), .dot, .parenthesis(.left), .parenthesis(.right),
        .function(.sin), .function(.cos), .function(.tan), .equal
    ]

    var title: String {
        switch self {
        case .digit(let value):
            return String(value)
        case .dot:
            return "."
        case .op(let op):
            return op.rawValue
        case .equal:
            return "="
        case .clear:
            return "C"
        case .history:
            return "History"
        case .toggleSign:
            return "+/−"
        case .percent:
            return "%"
        case .backspace:
            return "⌫"
        case .parenthesis(let side):
            return side == .left ? "(" : ")"
        case .function(let fn):
            return fn.title
        case .memory(let action):
            return action.title
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .digit(let value):
            return "Digit \(value)"
        case .dot:
            return "Decimal point"
        case .op(let op):
            return op.accessibilityLabel
        case .equal:
            return "Calculate result"
        case .clear:
            return "Clear calculator"
        case .history:
            return "Show history"
        case .toggleSign:
            return "Toggle sign"
        case .percent:
            return "Percent"
        case .backspace:
            return "Delete last character"
        case .parenthesis(let side):
            return side == .left ? "Open parenthesis" : "Close parenthesis"
        case .function(let fn):
            return fn.accessibilityLabel
        case .memory(let action):
            return action.accessibilityLabel
        }
    }

    var accessibilityHint: String {
        switch self {
        case .digit, .dot:
            return "Adds to the current number"
        case .op:
            return "Sets the operator"
        case .equal:
            return "Evaluates the current expression"
        case .clear:
            return "Resets the calculator"
        case .history:
            return "Opens the history list"
        case .toggleSign:
            return "Switches between positive and negative"
        case .percent:
            return "Converts the number to a percent"
        case .backspace:
            return "Removes the last digit"
        case .parenthesis:
            return "Adds a parenthesis to the expression"
        case .function:
            return "Applies a scientific function"
        case .memory:
            return "Memory controls"
        }
    }
}

enum OperatorType: String {
    case add = "+"
    case subtract = "-"
    case multiply = "×"
    case divide = "÷"

    var expressionSymbol: String {
        switch self {
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "*"
        case .divide: return "/"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .add:
            return "Add"
        case .subtract:
            return "Subtract"
        case .multiply:
            return "Multiply"
        case .divide:
            return "Divide"
        }
    }
}

enum ExpressionToken: Equatable {
    case number(Double)
    case `operator`(OperatorType)
    case parenthesis(ParenthesisSide)
}

private extension Array where Element == ExpressionToken {
    var lastNumber: Double? {
        for token in reversed() {
            if case .number(let value) = token { return value }
        }
        return nil
    }

    var containsNumber: Bool {
        contains { token in
            if case .number = token { return true }
            return false
        }
    }
}

private extension ExpressionToken {
    var isLeftParenthesis: Bool {
        if case .parenthesis(.left) = self { return true }
        return false
    }
}

extension HistoryEntry {
    var resultFormatted: String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: result)) ?? String(result)
    }
}

enum ParenthesisSide { case left, right }

enum FunctionType: CaseIterable {
    case sin, cos, tan, sqrt, square, reciprocal

    var title: String {
        switch self {
        case .sin: return "sin"
        case .cos: return "cos"
        case .tan: return "tan"
        case .sqrt: return "√"
        case .square: return "x²"
        case .reciprocal: return "1/x"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .sin: return "Sine"
        case .cos: return "Cosine"
        case .tan: return "Tangent"
        case .sqrt: return "Square root"
        case .square: return "Square"
        case .reciprocal: return "Reciprocal"
        }
    }
}

enum MemoryAction: CaseIterable {
    case mc, mr, mPlus, mMinus

    var title: String {
        switch self {
        case .mc: return "MC"
        case .mr: return "MR"
        case .mPlus: return "M+"
        case .mMinus: return "M-"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .mc: return "Memory clear"
        case .mr: return "Memory recall"
        case .mPlus: return "Add to memory"
        case .mMinus: return "Subtract from memory"
        }
    }
}

enum ThemeOption: String, CaseIterable {
    case classic, ocean, forest

    var title: String { rawValue.capitalized }

    var accentColor: Color {
        switch self {
        case .classic: return .orange
        case .ocean: return .blue
        case .forest: return .green
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
