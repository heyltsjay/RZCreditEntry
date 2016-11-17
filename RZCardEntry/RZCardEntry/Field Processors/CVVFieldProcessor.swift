//
//  CVVFieldProcessor.swift
//  RZCardEntry
//
//  Created by Jason Clark on 11/8/16.
//  Copyright © 2016 Raizlabs. All rights reserved.
//

import UIKit

class CVVFieldProcessor: FieldProcessor {

    var cardState: CardState = .indeterminate(CardType.allValues)

    override var textField: UITextField? {
        didSet {
            textField?.placeholder = "CVV"
        }
    }

    override init() {
        super.init()

        inputCharacterSet = .decimalDigits
    }

    var maxLength: Int {
        switch cardState {
        case .identified(let card): return card.cvvLength
        default: return 3
        }
    }

    override var valid: Bool {
        return unformattedText(textField).characters.count == maxLength
    }

    override func validateAndFormat(edit: EditingEvent) -> ValidationResult {
        if removeFormatting(edit.newValue).characters.count <= maxLength {
            return .valid(edit.newValue, edit.newCursorPosition)
        }
        else {
            return .invalid
        }
    }

}