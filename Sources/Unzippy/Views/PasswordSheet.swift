import SwiftUI
import AppKit
import UnzippyCore

struct PasswordSheet: View {
    let prompt: PasswordPrompt
    @EnvironmentObject private var model: AppModel
    @State private var password = ""
    @State private var remember = Prefs.rememberPasswords
    @State private var localError: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(Theme.amber.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Theme.amber)
                }
                Text("这个压缩包需要密码")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(prompt.archiveName)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 22)

            VStack(spacing: 9) {
                SecureField("输入密码", text: $password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($focused)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(localError != nil || prompt.message != nil ? Theme.rose.opacity(0.5) : Theme.hairline, lineWidth: 1)
                    )
                    .onSubmit(submit)

                if let message = localError ?? prompt.message {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 9))
                        Text(message)
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.rose)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Toggle("记住密码（保存到钥匙串）", isOn: $remember)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 26)
            .padding(.top, 18)

            Spacer(minLength: 16)
            HStack(spacing: 8) {
                Spacer()
                Button("取消") { model.dismissPasswordPrompt() }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("继续") { submit() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 380, height: 296)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { focused = true }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        localError = nil
        model.submitPassword(password, remember: remember)
    }
}
