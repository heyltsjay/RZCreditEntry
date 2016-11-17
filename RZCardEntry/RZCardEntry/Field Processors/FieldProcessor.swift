//
//  FieldProcessor.swift
//  RZCardEntry
//
//  Created by Jason Clark on 11/8/16.
//  Copyright © 2016 Raizlabs. All rights reserved.
//

import UIKit

//MARK: - protocols, structs, enums
//TODO: move these
protocol FormValidation {
    var valid: Bool { get }
}

protocol FormNavigation {
    @discardableResult func fieldProcessor(_ fieldProcessor: FieldProcessor, navigation: CharacterNavigation) -> Bool
}

enum CharacterNavigation {
    case backspace
    case overflow(String)
}

struct EditingEvent {
    var oldValue: String
    var editRange: NSRange
    var editString: String
    var newValue: String
    var newCursorPosition: Int
}

enum ValidationResult {
    case valid(String, Int)
    case invalid
}

//MARK: - FieldProcessor
class FieldProcessor: NSObject, FormValidation {

    weak var textField: UITextField? {
        didSet {
            textField?.delegate = self
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.addObserver(self, selector: #selector(textFieldDidDeleteBackwardNotification(note:)), name: Notification.Name(rawValue: UITextField.deleteBackwardNotificationName), object:textField)
        }
    }

    var inputCharacterSet = CharacterSet.alphanumerics
    var formattingCharacterSet = CharacterSet()
    var deletingShouldRemoveTrailingCharacters = false
    var navigationDelegate: FormNavigation?

    var valid: Bool {
        return true
    }

    func inputInvalid(textField: UITextField) {
        //TODO: hook for override
        textField.shake()
    }

    func validateAndFormat(edit: EditingEvent) -> ValidationResult {
        return .valid(edit.newValue, edit.newCursorPosition)
    }

    func containsValidChars(text: String?)->Bool {
        let allowedSet = inputCharacterSet.union(formattingCharacterSet)
        let rangeOfInvalidChar = text?.rangeOfCharacter(from: allowedSet.inverted)
        guard rangeOfInvalidChar?.isEmpty ?? true else { return false }

        return true
    }

}

extension FieldProcessor {

    func unformattedText(_ textField: UITextField?) -> String {
        guard let text = textField?.text else { return "" }
        return removeFormatting(text)
    }

    func removeFormatting(_ text: String) -> String {
        return text.filteringWith(characterSet: inputCharacterSet)
    }

    func removeFormatting(_ text: String, cursorPosition: inout Int) -> String {
        return text.filteringWith(characterSet: inputCharacterSet, cursorPosition: &cursorPosition)
    }

}

extension String {

    func filteringWith(characterSet: CharacterSet) -> String {
        return components(separatedBy: characterSet.inverted).joined()
    }

    func filteringWith(characterSet: CharacterSet, cursorPosition: inout Int) -> String {
        let originalCursorPosition = cursorPosition
        var validChars = String()
        for (index, character) in characters.enumerated() {
            if String(character).rangeOfCharacter(from: characterSet) != nil {
                validChars.append(character)
            }
            else if index < originalCursorPosition {
                cursorPosition -= 1
            }
        }
        return validChars
    }

}

extension FieldProcessor: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard containsValidChars(text: string) else {
            inputInvalid(textField: textField)
            return false
        }
        //if user is inserting text at the end of a valid text field, alert delegate to potentially forward the input
        if range.location == textField.text?.characters.count && string.characters.count > 0 && valid {
            let _ = navigationDelegate?.fieldProcessor(self, navigation: .overflow(string))
            //maybe do something here if we didn't overflow
            return false
        }

        let adjustedRange = handleDeletionOfFormatting(textField: textField, range: range, replacementString: string)

        if let range = textField.text?.range(fromNSRange: adjustedRange) {
            let newText = textField.text?.replacingCharacters(in: range, with: string)
            let newRange = adjustedRange.location + string.characters.count

            let event = EditingEvent(oldValue: textField.text ?? "",
                                     editRange: adjustedRange,
                                     editString: string,
                                     newValue: newText ?? "",
                                     newCursorPosition: newRange)

            let result =  validateAndFormat(edit: event)
            if case .valid(let string, let cursorPosition) = result {
                textField.text = string
                textField.selectedTextRange = textField.textRange(cursorOffset: cursorPosition)
                textField.sendActions(for: .editingChanged)
            }
            else {
                inputInvalid(textField: textField)
                return false
            }
        }
        return false
    }

}

extension FieldProcessor {

    @objc func textFieldDidDeleteBackwardNotification(note: NSNotification) {
        if let textField = note.object as? UITextField, textField.text?.characters.count == 0 {
            navigationDelegate?.fieldProcessor(self, navigation: .backspace)
        }
    }

}

private extension FieldProcessor {

    func handleDeletionOfFormatting(textField: UITextField, range: NSRange, replacementString string: String) -> NSRange {
        var adjustedRange = range
        guard let text = textField.text else { return adjustedRange }
        let deletedSingleChar = range.length == 1
        let noTextSelected = textField.selectedTextRange?.isEmpty ?? true
        if (deletedSingleChar && noTextSelected) {
            let range = text.range(fromNSRange: range)
            let deletedSingleFormattingChar = text.rangeOfCharacter(from: formattingCharacterSet, options: NSString.CompareOptions(), range: range) != nil
            if deletedSingleFormattingChar {
                let selection = textField.selectedTextRange
                textField.text?.removeSubrange(range)
                if let selection = selection, let offset = textField.offsetTextRange(selection, by: -1) {
                    adjustedRange.location = adjustedRange.location - 1
                    textField.selectedTextRange = offset
                }
            }
        }
        if range.length > 0 && deletingShouldRemoveTrailingCharacters {
            if let selectedTextRange = textField.selectedTextRange {
                let offset = textField.offset(from: textField.beginningOfDocument, to: selectedTextRange.end)
                textField.text = textField.text?.substring(to: text.characters.index(text.startIndex, offsetBy: offset))
            }
        }
        return adjustedRange
    }

}