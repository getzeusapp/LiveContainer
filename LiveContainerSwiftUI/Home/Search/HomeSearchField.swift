//
//  HomeSearchField.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Search's field, as iOS 26.5's Spotlight draws it. On iPhone it's a glass
/// capsule 48 points tall at the bottom of search, the magnifying glass 12
/// points in, the text 8 points beyond it in 17-point medium white, the
/// placeholder in white at 25%, and while something is typed a clear button,
/// a white circle with its X cut out. On iPad it's the row along the top of
/// search's panel, with a line under it, in bigger text, its glass and clear
/// button in white at 60% (`isPadRow`). There's no close button: a tap
/// beside the results closes search, and on iPad Escape does too.
struct HomeSearchField: View {
    /// What is typed.
    @Binding var text: String
    /// Whether the field has the keyboard.
    var isFocused: FocusState<Bool>.Binding
    /// Opens the best match, as the keyboard's Search key does.
    let onSubmit: () -> Void
    /// Closes search.
    let onClose: () -> Void
    /// Whether it's the row along the top of iPad's panel rather than
    /// iPhone's capsule.
    var isPadRow = false

    var body: some View {
        if isPadRow {
            padRow
        } else {
            capsule
        }
    }

    private var capsule: some View {
        HStack(spacing: HomeDesign.searchFieldIconSpacing) {
            magnifyingGlass(size: HomeDesign.searchFieldFontSize, opacity: 1)
            field(fontSize: HomeDesign.searchFieldFontSize, placeholderOpacity: HomeDesign.searchFieldPlaceholderOpacity)
            if !text.isEmpty {
                clearButton(size: HomeDesign.searchFieldFontSize, weight: .regular, opacity: 1)
            }
        }
        .padding(.leading, HomeDesign.searchFieldLeadingInset)
        .padding(.trailing, text.isEmpty ? HomeDesign.searchFieldLeadingInset : HomeDesign.searchFieldClearButtonInset)
        .frame(height: HomeDesign.searchFieldHeight)
        .homeGlass(.capsule)
    }

    private var padRow: some View {
        HStack(spacing: 0) {
            magnifyingGlass(size: HomeDesign.padSearchFieldIconSize, opacity: HomeDesign.padSearchFieldSymbolOpacity)
                .offset(y: -HomeDesign.padSearchFieldIconRaise)
                .padding(.leading, HomeDesign.padSearchFieldIconInset)
                .frame(width: HomeDesign.padSearchFieldTextInset, alignment: .leading)
            field(fontSize: HomeDesign.padSearchFieldFontSize, placeholderOpacity: HomeDesign.padSearchFieldPlaceholderOpacity)
            if !text.isEmpty {
                clearButton(size: HomeDesign.padSearchFieldClearSize, weight: .medium, opacity: HomeDesign.padSearchFieldSymbolOpacity)
                    .offset(y: -HomeDesign.padSearchFieldIconRaise)
                    .padding(.trailing, HomeDesign.padSearchFieldClearButtonInset)
            }
        }
        .padding(.trailing, text.isEmpty ? HomeDesign.padSearchMargin : 0)
        .frame(height: HomeDesign.padSearchFieldHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(HomeDesign.padSearchFieldSeparatorOpacity))
                .frame(height: 1)
                .padding(.horizontal, HomeDesign.padSearchMargin)
                .accessibilityHidden(true)
        }
    }

    private func magnifyingGlass(size: Double, opacity: Double) -> some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(.white.opacity(opacity))
            .accessibilityHidden(true)
    }

    private func field(fontSize: Double, placeholderOpacity: Double) -> some View {
        TextField(text: $text, prompt: placeholder(opacity: placeholderOpacity)) {
            Text("zc.home.search".loc)
        }
        .font(.system(size: fontSize, weight: .medium))
        .foregroundStyle(.white)
        .tint(.white)
        .focused(isFocused)
        .submitLabel(.search)
        .onSubmit(onSubmit)
        .onKeyPress(.escape, action: escapePressed)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .background(HomeSearchKeyboardSetup())
    }

    private func clearButton(size: Double, weight: Font.Weight, opacity: Double) -> some View {
        Button(action: clear) {
            Label("zc.home.clearSearch".loc, systemImage: "xmark.circle.fill")
                .labelStyle(.iconOnly)
                .font(.system(size: size, weight: weight))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.white.opacity(opacity))
                .frame(width: HomeDesign.minimumTouchSize, height: HomeDesign.minimumTouchSize)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func placeholder(opacity: Double) -> Text {
        Text("zc.home.search".loc)
            .foregroundStyle(.white.opacity(opacity))
    }

    private func clear() {
        text = ""
    }

    /// On iPad, Escape on a hardware keyboard closes search, as it closes
    /// Spotlight. On iPhone the key goes on as before.
    private func escapePressed() -> KeyPress.Result {
        guard !SharedModel.isPhone else {
            return .ignored
        }
        onClose()
        return .handled
    }
}

/// Sets up the keyboard of the text field SwiftUI draws the search field
/// with, as Spotlight's: no bar of predictions over it, nor shortcuts on
/// iPad, no spelling or autocorrection, and the Search key only once
/// something is typed. SwiftUI has no say over these, so it reaches the field
/// itself, next to this view, as it goes on screen.
private struct HomeSearchKeyboardSetup: UIViewRepresentable {
    func makeUIView(context: Context) -> SetupView {
        SetupView()
    }

    func updateUIView(_ view: SetupView, context: Context) {}

    final class SetupView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isHidden = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else {
                return
            }
            // After SwiftUI has put the field in place.
            DispatchQueue.main.async { [weak self] in
                self?.setUpField()
            }
        }

        private func setUpField() {
            var ancestor = superview
            while let view = ancestor {
                if let field = Self.textField(in: view) {
                    Self.setUp(field)
                    return
                }
                ancestor = view.superview
            }
        }

        private static func textField(in view: UIView) -> UITextField? {
            if let field = view as? UITextField {
                return field
            }
            for subview in view.subviews {
                if let field = textField(in: subview) {
                    return field
                }
            }
            return nil
        }

        private static func setUp(_ field: UITextField) {
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.smartQuotesType = .no
            field.smartDashesType = .no
            field.smartInsertDeleteType = .no
            field.inlinePredictionType = .no
            field.enablesReturnKeyAutomatically = true
            field.inputAssistantItem.leadingBarButtonGroups = []
            field.inputAssistantItem.trailingBarButtonGroups = []
            if field.isFirstResponder {
                field.reloadInputViews()
            }
        }
    }
}
