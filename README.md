# iOS-Calculator-Project
Calculator App Features:
User Interface (UI):

The main screen of the app consists of a calculator display, buttons for digits, arithmetic operators, a decimal point, clear button (C), equal button (=), and a history button.
Dark Mode:

The app supports a toggle for Dark Mode, changing the color scheme between light and dark.
History:

The app keeps track of the calculation history, and users can view it through a "History" button.
Core Logic:
State Variables:

displayText: Represents the text displayed on the calculator.
currentInput: Stores the current user input.
equation: Stores the entire equation.
firstOperand: Holds the first operand in a binary operation.
currentOperator: Keeps track of the current binary operator.
history: Array to store calculation history.
isDarkMode: A flag to toggle between light and dark modes.
isHistorySheetPresented: Flag to control the visibility of the history sheet.
Button Layout:

The calculator buttons are arranged in a 2D array (buttons), representing rows and columns.
Button Actions:

buttonPressed(_:): Handles the action when a calculator button is pressed.
handleDigit(_:): Appends a digit to the current input and updates the display.
handleDot(): Adds a decimal point to the current input if not present.
handleOperator(_:): Handles binary operator input and updates the equation.
calculateResult(): Performs the final operation and updates the display.
clearCalculator(): Clears the calculator state.
resetCalculator(): Resets the calculator state.
addToHistory(_:): Adds an entry to the calculation history.
showHistory(): Displays the calculation history sheet.
SwiftUI Views:
ContentView:

The main view that orchestrates the layout of the calculator.
Integrates dark mode, history sheet, and button actions.
CalculatorButtonView:

Represents an individual calculator button with a specific action.
Adjusts its appearance based on the color scheme.
HistoryView:

Displays the calculation history in a separate sheet.
Enums:
CalculatorButton:

Enumerates the types of calculator buttons (digits, operators, etc.).
Provides a computed property for the button title.
OperatorType:

Enumerates the types of binary operators (add, subtract, multiply, divide).
Preview:
ContentView_Previews:
Provides a preview of the main ContentView.
Additional Notes:
Detailed Comments:

The code is thoroughly documented with comments to explain each function and section, aiding readability.
Modular Design:

The code is structured with a modular design, separating concerns for better maintainability.
This calculator app follows a classic design, supporting basic arithmetic operations with a history feature and the flexibility to switch between light and dark modes.
