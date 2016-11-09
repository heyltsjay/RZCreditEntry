//
//  FieldProcessor.swift
//  RZCardEntry
//
//  Created by Jason Clark on 11/8/16.
//  Copyright © 2016 Raizlabs. All rights reserved.
//

import UIKit

protocol FormValidation {
    var valid: Bool { get }
}

class FieldProcessor: NSObject, FormValidation {

    weak var textField: UITextField? {
        didSet {
            textField?.delegate = self
            textField?.addTarget(self, action: #selector(editingChanged(textField:)), for: .editingChanged)
        }
    }

    var inputCharacterSet = CharacterSet.alphanumerics
    var formattingCharacterSet = CharacterSet()
    var deletingShouldRemoveTrailingCharacters = false

    var valid: Bool {
        return true
    }

    func isValid(replacementString: String) -> Bool {
        let allowedSet = inputCharacterSet.union(formattingCharacterSet)
        let rangeOfInvalidChar = replacementString.rangeOfCharacter(from: allowedSet.inverted)
        return rangeOfInvalidChar?.isEmpty ?? true
    }

    func inputInvalid(textField: UITextField) {
        //TODO: hook for override
        textField.shake()
    }

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

    func editingChanged(textField: UITextField) {
        reformat()
    }

    func reformat() {

    }

    func newTextIsValid(text: String?)->Bool {
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
        //if user is inserting text at the end of a valid text field, alert delegate to potentially forward the input
        if range.location == textField.text?.characters.count && string.characters.count > 0 && valid {
            //textField.navigationDelegate?.textField(textField, shouldForwardInput: string)
            return false
        }

        let adjustedRange = handleDeletionOfFormatting(textField: textField, range: range, replacementString: string)

        if let range = textField.text?.range(fromNSRange: adjustedRange) {
            let newText = textField.text?.replacingCharacters(in: range, with: string)
            if newTextIsValid(text: newText) {
//                textField.text = newText
//                reformat()
                return true
            }
            else {
                inputInvalid(textField: textField)
                return false
            }
        }
        return false
    }

}
