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
    @State private var displayText: String = "" // Displayed text on the calculator
    @State private var currentInput: String = "" // Current user input
    @State private var equation: String = "" // The entire equation being built
    @State private var firstOperand: Double? // The first operand in a binary operation
    @State private var currentOperator: OperatorType? // The current binary operator
    @State private var history: [String] = [] // Keep track of the calculation history
    @State private var isDarkMode: Bool = false // Flag to toggle dark mode

    @State private var isHistorySheetPresented: Bool = false // Flag to present the history sheet

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
            }

            Spacer()

            // Display area for the calculator
            Text(displayText)
                .font(.system(size: 64))
                .padding()
                .frame(width: 300, height: 80, alignment: .trailing)
                .lineLimit(1)
                .foregroundColor(isDarkMode ? .white : .black)

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
        .environment(\.colorScheme, isDarkMode ? .dark : .light)
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
        equation.append(String(digit))
        displayText = equation
    }

    // Function to handle dot (decimal point) input
    func handleDot() {
        if !currentInput.contains(".") {
            currentInput.append(".")
            equation.append(".")
            displayText = equation
        }
    }

    // Function to handle binary operator input
    func handleOperator(_ operatorType: OperatorType) {
        if let currentOperator = currentOperator, let currentOperand = Double(currentInput) {
            // If there was a previous operator, perform the operation
            switch currentOperator {
            case .add:
                firstOperand! += currentOperand
            case .subtract:
                firstOperand! -= currentOperand
            case .multiply:
                firstOperand! *= currentOperand
            case .divide:
                if currentOperand != 0 {
                    firstOperand! /= currentOperand
                } else {
                    // Handle division by zero
                    // For simplicity, we reset the calculator
                    resetCalculator()
                    return
                }
            }
        } else {
            // If there was no previous operator, set the current display value as the first operand
            firstOperand = Double(currentInput)
        }

        // Update the operator, equation, and reset the current input
        currentOperator = operatorType
        equation.append(" \(currentOperator!.rawValue) ")
        currentInput = ""

        // Update the display with the entire equation
        displayText = equation
    }

    // Function to calculate the result of the expression
    func calculateResult() {
        guard let currentOperator = currentOperator, let currentOperand = Double(currentInput) else {
            return
        }

        // Perform the final operation
        switch currentOperator {
        case .add:
            firstOperand! += currentOperand
        case .subtract:
            firstOperand! -= currentOperand
        case .multiply:
            firstOperand! *= currentOperand
        case .divide:
            if currentOperand != 0 {
                firstOperand! /= currentOperand
            } else {
                // Handle division by zero
                resetCalculator()
                return
            }
        }

        // Display the answer in the output
        displayText = String(firstOperand!)

        // Add the entire equation and result to history
        addToHistory("\(equation) = \(displayText)")

        // Reset the calculator after calculating the result
        resetCalculator()
    }

    // Function to clear the calculator
    func clearCalculator() {
        currentInput = ""
        equation = ""
        displayText = ""
        firstOperand = nil
        currentOperator = nil
    }

    // Function to reset the calculator
    func resetCalculator() {
        currentInput = ""
        equation = ""
        firstOperand = nil
        currentOperator = nil
    }

    // Function to add an entry to the calculation history
    func addToHistory(_ entry: String) {
        history.append(entry)
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
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .background(buttonBackgroundColor)
                .cornerRadius(8)
        }
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
            }
            .navigationBarTitle("History", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                // Dismiss the sheet
                self.presentationMode.wrappedValue.dismiss()
            })
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
}

// Enum representing the types of binary operators
enum OperatorType: String {
    case add = "+"
    case subtract = "-"
    case multiply = "×"
    case divide = "÷"
}

// PreviewProvider for the ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
