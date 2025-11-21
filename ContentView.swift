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

    var body: some View {
        VStack(spacing: 16) {
            header

            Spacer()

            display

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
            }

            buttonGrid
        }
        .padding()
        .background(backgroundColor)
        .environment(.colorScheme, isDarkMode ? .dark : .light)
    }

    private var header: some View {
        HStack {
            Spacer()
            Button(action: {
                withAnimation { isDarkMode.toggle() }
            }) {
                Image(systemName: isDarkMode ? "sun.max" : "moon")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(isDarkMode ? .white : .black)
                    .padding()
            }
            .accessibilityLabel(isDarkMode ? "Disable dark mode" : "Enable dark mode")
            .accessibilityHint("Toggles the calculator appearance")
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
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    private var buttonGrid: some View {
        VStack(spacing: 8) {
            ForEach(Array(CalculatorButton.allRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { button in
                        CalculatorButtonView(button: button, onTap: { viewModel.handle(button) })
                    }
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
            return
        }

        if let last = tokens.last, case .operator = last { tokens.removeLast() }
        tokens.append(.operator(operatorType))
    }

    private func calculateResult() {
        guard commitCurrentInput() || (!tokens.isEmpty && currentInput.isEmpty) else {
            errorMessage = "Complete the expression before calculating."
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
            }
        }

        if !currentInput.isEmpty { parts.append(currentInput) }
        equationText = parts.joined(separator: " ")
    }

    private func evaluateTokens(_ tokens: [ExpressionToken]) -> Result<Double, String> {
        var workingTokens = tokens

        for index in 0..<workingTokens.count {
            let isEven = index % 2 == 0
            let token = workingTokens[index]
            if isEven, case .operator = token {
                return .failure("Expression cannot start with an operator.")
            }
            if !isEven, case .number = token {
                return .failure("Operators must be between numbers.")
            }
        }

        if let last = workingTokens.last, case .operator = last {
            return .failure("Expression cannot end with an operator.")
        }

        var reducedTokens: [ExpressionToken] = []
        var index = 0

        while index < workingTokens.count {
            let token = workingTokens[index]
            switch token {
            case .number:
                reducedTokens.append(token)
                index += 1
            case .operator(let op) where (op == .multiply || op == .divide):
                guard let lastNumberToken = reducedTokens.popLast(), case .number(let lhs) = lastNumberToken else {
                    return .failure("Invalid expression structure.")
                }

                guard index + 1 < workingTokens.count, case .number(let rhs) = workingTokens[index + 1] else {
                    return .failure("Operator must be followed by a number.")
                }

                if op == .divide && rhs == 0 {
                    return .failure("Cannot divide by zero.")
                }

                let result = op == .multiply ? lhs * rhs : lhs / rhs
                reducedTokens.append(.number(result))
                index += 2
            case .operator:
                reducedTokens.append(token)
                index += 1
            }
        }

        guard let firstNumberToken = reducedTokens.first, case .number(let first) = firstNumberToken else {
            return .failure("Invalid expression.")
        }

        var result = first
        index = 1
        while index < reducedTokens.count - 1 {
            guard case .operator(let op) = reducedTokens[index], case .number(let rhs) = reducedTokens[index + 1] else {
                return .failure("Invalid expression.")
            }

            switch op {
            case .add:
                result += rhs
            case .subtract:
                result -= rhs
            case .multiply, .divide:
                break
            }

            index += 2
        }

        return .success(result)
    }

    private func formattedNumber(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func provideHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
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

    var body: some View {
        NavigationView {
            List {
                ForEach(history) { entry in
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
                }
                .onDelete(perform: onDelete)
            }
            .navigationBarTitle("History", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .accessibilityLabel("Close history")
            .accessibilityHint("Dismisses the history list"))
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

    static let allRows: [[CalculatorButton]] = [
        [.clear, .toggleSign, .percent, .backspace],
        [.digit(7), .digit(8), .digit(9), .op(.divide)],
        [.digit(4), .digit(5), .digit(6), .op(.multiply)],
        [.digit(1), .digit(2), .digit(3), .op(.subtract)],
        [.digit(0), .dot, .history, .op(.add)],
        [.equal]
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
        }
    }
}

enum OperatorType: String {
    case add = "+"
    case subtract = "-"
    case multiply = "×"
    case divide = "÷"

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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
