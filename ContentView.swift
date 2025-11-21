//
//  ContentView.swift
//  iOS Calculator Project
//
//  Created by Gabriel Ritter on 1/30/24.
//

import SwiftUI

// The main ContentView struct, representing the calculator screen
struct ContentView: View {
    // State variables to track various aspects of the calculator
    @State private var displayText: String = "0" // Displayed text on the calculator
    @State private var currentInput: String = "" // Current user input
    @State private var tokens: [ExpressionToken] = [] // The expression being built
    @State private var history: [String] = [] // Keep track of the calculation history
    @State private var isDarkMode: Bool = false // Flag to toggle dark mode

    @State private var isHistorySheetPresented: Bool = false // Flag to present the history sheet
    @State private var alertMessage: AlertMessage? // Error message to present in an alert

    // 2D array representing the layout of buttons on the calculator
    let buttons: [[CalculatorButton]] = [
        [.digit(7), .digit(8), .digit(9), .op(.divide)],
        [.digit(4), .digit(5), .digit(6), .op(.multiply)],
        [.digit(1), .digit(2), .digit(3), .op(.subtract)],
        [.digit(0), .dot, .op(.add)],
        [.clear, .equal, .history] // Added equal button
    ]

    // The body of the ContentView
    var body: some View {
        VStack(spacing: 12) {
            // Dark mode toggle button
            HStack {
                Spacer()
                Button(action: {
                    // Toggle dark mode
                    withAnimation {
                        isDarkMode.toggle()
                    }
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

            Spacer()

            // Display area for the calculator
            VStack(alignment: .trailing, spacing: 8) {
                Text(equationText)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("Equation")
                    .accessibilityHint("Shows the full expression")

                Text(displayText)
                    .font(.system(size: 64))
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(isDarkMode ? .white : .black)
                    .accessibilityLabel("Display")
                    .accessibilityHint("Shows the current number or result")
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)

            // Grid of calculator buttons
            VStack(spacing: 8) {
                ForEach(buttons, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { button in
                            CalculatorButtonView(button: button, onTap: buttonPressed(_:))
                        }
                    }
                }
            }
        }
        .padding()
        .background(backgroundColor)
        .sheet(isPresented: $isHistorySheetPresented) {
            HistoryView(history: self.history)
        }
        .alert(item: $alertMessage, content: { message in
            Alert(title: Text("Error"), message: Text(message.text), dismissButton: .default(Text("OK")))
        })
        .environment(.colorScheme, isDarkMode ? .dark : .light)
    }

    // Function to handle button presses
    func buttonPressed(_ button: CalculatorButton) {
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
            showHistory()
        }
    }

    // Function to handle digit input
    func handleDigit(_ digit: Int) {
        currentInput.append(String(digit))
        updateDisplay()
    }

    // Function to handle dot (decimal point) input
    func handleDot() {
        if !currentInput.contains(".") {
            if currentInput.isEmpty {
                currentInput = "0"
            }
            currentInput.append(".")
            updateDisplay()
        }
    }

    // Function to handle binary operator input
    func handleOperator(_ operatorType: OperatorType) {
        if !commitCurrentInput() && tokens.isEmpty {
            alertMessage = AlertMessage(text: "Enter a number before selecting an operator.")
            return
        }

        if let last = tokens.last, case .operator = last {
            tokens.removeLast()
        }

        tokens.append(.operator(operatorType))
        currentInput = ""
        updateDisplay()
    }

    // Function to calculate the result of the expression
    func calculateResult() {
        guard commitCurrentInput() || (!tokens.isEmpty && currentInput.isEmpty) else {
            alertMessage = AlertMessage(text: "Complete the expression before calculating.")
            return
        }

        guard tokens.containsNumber else {
            alertMessage = AlertMessage(text: "Enter a number to calculate.")
            return
        }

        let expressionString = equationText
        switch evaluateTokens(tokens) {
        case .success(let value):
            displayText = formattedNumber(value)
            history.append("\(expressionString) = \(displayText)")
            tokens = [.number(value)]
            currentInput = ""
            updateDisplay()
        case .failure(let error):
            alertMessage = AlertMessage(text: error)
            resetCalculator()
        }
    }

    // Function to clear the calculator
    func clearCalculator() {
        currentInput = ""
        tokens = []
        displayText = "0"
    }

    // Function to reset the calculator
    func resetCalculator() {
        currentInput = ""
        tokens = []
        displayText = "0"
    }

    // Function to show the calculation history sheet
    func showHistory() {
        isHistorySheetPresented.toggle()
    }

    // Function to determine the background color based on dark mode
    var backgroundColor: Color {
        if isDarkMode {
            return Color.black
        } else {
            return Color.white
        }
    }

    // Computed property representing the full equation as text
    var equationText: String {
        var parts: [String] = tokens.map { token in
            switch token {
            case .number(let value):
                return formattedNumber(value)
            case .operator(let op):
                return op.rawValue
            }
        }

        if !currentInput.isEmpty {
            parts.append(currentInput)
        }

        return parts.isEmpty ? "" : parts.joined(separator: " ")
    }

    // Commit the current input as a number token
    @discardableResult
    func commitCurrentInput() -> Bool {
        guard !currentInput.isEmpty else { return false }
        guard let value = Double(currentInput) else {
            alertMessage = AlertMessage(text: "Invalid number format.")
            return false
        }

        tokens.append(.number(value))
        currentInput = ""
        return true
    }

    // Update the displayed text based on equation and current input
    func updateDisplay() {
        if !currentInput.isEmpty {
            displayText = currentInput
        } else if let lastNumber = tokens.lastNumber {
            displayText = formattedNumber(lastNumber)
        } else {
            displayText = "0"
        }
    }

    // Evaluate expression tokens with basic operator precedence
    func evaluateTokens(_ tokens: [ExpressionToken]) -> Result<Double, String> {
        var workingTokens = tokens

        // Validate alternating number/operator pattern
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

        // Ensure expression ends with number
        if let last = workingTokens.last, case .operator = last {
            return .failure("Expression cannot end with an operator.")
        }

        // First handle multiplication and division
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

        // Then handle addition and subtraction
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
                // Already handled in previous pass
                break
            }

            index += 2
        }

        return .success(result)
    }

    // Format numbers to avoid trailing zeros
    func formattedNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(value)
    }
}

// Subview representing an individual calculator button
struct CalculatorButtonView: View {
    let button: CalculatorButton
    let onTap: (CalculatorButton) -> Void

    @Environment(\.colorScheme) var colorScheme

    // The body of the CalculatorButtonView
    var body: some View {
        Button(action: {
            self.onTap(self.button)
        }) {
            Text(button.title)
                .font(.system(size: 24))
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

    // Function to determine the button background color based on dark mode
    var buttonBackgroundColor: Color {
        if colorScheme == .dark {
            return Color.gray.opacity(0.5)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
}

// Subview representing the history view
struct HistoryView: View {
    @Environment(\.presentationMode) var presentationMode
    var history: [String]

    // The body of the HistoryView
    var body: some View {
        NavigationView {
            List(history, id: \.self) { entry in
                Text(entry)
                    .accessibilityLabel("Past calculation")
            }
            .navigationBarTitle("History", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                // Dismiss the sheet
                self.presentationMode.wrappedValue.dismiss()
            }
            .accessibilityLabel("Close history")
            .accessibilityHint("Dismisses the history list"))
        }
    }
}

// Enum representing the types of calculator buttons
enum CalculatorButton: Hashable {
    case digit(Int)
    case dot
    case op(OperatorType)
    case equal
    case clear
    case history

    // Computed property to get the title of the button
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
        }
    }
}

// Enum representing the types of binary operators
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

// Expression token representing either a number or an operator
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

struct AlertMessage: Identifiable {
    let id = UUID()
    let text: String
}

// PreviewProvider for the ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
