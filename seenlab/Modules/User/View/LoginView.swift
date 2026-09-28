//
//  LoginView.swift
//  seenlab
//
//  Sign in, in the web login's voice ("Nazad u laboratoriju"): warm paper, a handwritten note, and the
//  "jutros" log card that shows what waits inside.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var show = false
    @FocusState private var focus: Field?
    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image("Logo").resizable().scaledToFit().frame(height: 34).padding(.top, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text(t("sl.login.hand")).font(.hand(22)).foregroundStyle(Color.slAccent600)
                    Text(t("sl.login.title")).font(.dm(32, .bold)).tracking(-0.8).foregroundStyle(Color.slInk)
                    Text(t("sl.login.sub")).font(.dm(15)).foregroundStyle(Color.slInkMuted)
                }

                VStack(alignment: .leading, spacing: 14) {
                    field(t("sl.login.email")) {
                        TextField(t("admin.login.emailPlaceholder"), text: $email)
                            .textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($focus, equals: .email).submitLabel(.next).onSubmit { focus = .password }
                    }
                    field(t("sl.login.password")) {
                        HStack {
                            Group {
                                if show { TextField("", text: $password) } else { SecureField("", text: $password) }
                            }
                            .textContentType(.password).focused($focus, equals: .password).submitLabel(.go).onSubmit(submit)
                            Button { show.toggle() } label: { Image(systemName: show ? "eye.slash" : "eye").foregroundStyle(Color.slInkMuted) }
                                .accessibilityLabel(t("sl.login.toggle"))
                        }
                    }

                    if let error = auth.error {
                        Text(error).font(.dm(13, .medium)).foregroundStyle(Color.slBad)
                    }

                    Button(action: submit) {
                        HStack { Spacer(); if auth.busy { ProgressView().tint(.white) }; Text(auth.busy ? t("sl.login.busy") : t("sl.login.submit")); Spacer() }
                    }
                    .buttonStyle(SLButtonStyle(kind: .primary))
                    .disabled(auth.busy || email.isEmpty || password.isEmpty)
                    .padding(.top, 4)
                }

                peek
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.slPaper.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    private func submit() {
        guard !email.isEmpty, !password.isEmpty, !auth.busy else { return }
        focus = nil
        Task { await auth.login(email: email, password: password) }
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.dm(13, .semibold)).foregroundStyle(Color.slInkSoft)
            content()
                .font(.dm(16))
                .padding(.horizontal, 14).frame(height: 50)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slLineStrong, lineWidth: 1))
        }
    }

    /// "ovo te čeka": the morning log from the web login.
    private var peek: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("sl.login.peek")).font(.hand(20)).foregroundStyle(Color.slAccent600)
            SLCard {
                Text(t("sl.login.logTitle")).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted).padding(.bottom, 8)
                ForEach(["a", "b", "c", "d"], id: \.self) { k in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(k == "a" ? Color.slBad : k == "b" || k == "c" ? Color.slGood : Color.slAccent600).frame(width: 7, height: 7).padding(.top, 6)
                        Text(t("sl.login.log." + k)).font(.dm(13.5)).foregroundStyle(Color.slInkSoft)
                    }
                    .padding(.vertical, 3)
                }
                Text(t("sl.login.pitch")).font(.dm(12.5)).foregroundStyle(Color.slInkMuted).padding(.top, 10)
            }
        }
        .padding(.top, 10)
    }
}
