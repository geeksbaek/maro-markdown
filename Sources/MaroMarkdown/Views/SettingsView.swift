import SwiftUI

struct SettingsView: View {
    @AppStorage("editorFontSize") private var editorFontSize = 15.0
    @AppStorage("previewFontSize") private var previewFontSize = 16.0

    var body: some View {
        Form {
            HStack {
                Text("편집기 글자 크기")
                Spacer()
                Stepper("\(Int(editorFontSize)) pt", value: $editorFontSize, in: 11...28)
                    .frame(width: 140)
            }
            HStack {
                Text("미리보기 글자 크기")
                Spacer()
                Stepper("\(Int(previewFontSize)) pt", value: $previewFontSize, in: 12...28)
                    .frame(width: 140)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
