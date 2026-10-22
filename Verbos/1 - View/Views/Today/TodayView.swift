import SwiftUI

struct TodayView: View {
    @State private var viewModel = TodayViewModel()
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    StreakStrip(streak: viewModel.streak, days: viewModel.week)
                        .frame(maxWidth: .infinity)
                    VStack(spacing: 22) {
                        if let error = viewModel.errorMessage {
                            OperationErrorView(message: error, retry: viewModel.retry)
                        }
                        if let session = viewModel.session {
                            if session.isComplete { completion(session) }
                            else { question(session) }
                        } else if viewModel.errorMessage == nil {
                            introduction
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 650)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(themeManager.current.background)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.refresh().value }
            .task(id: scenePhase == .active ? viewModel.questionAwaitingAdvanceID : nil) {
                guard scenePhase == .active else { return }
                await viewModel.advanceAfterFeedback()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { viewModel.refresh() }
            }
            .background {
                // A foreground midnight must unlock the new day without restarting the app.
                DayBoundaryObserver { viewModel.refresh() }
            }
        }
        .toolbar(viewModel.isSessionInProgress ? .hidden : .visible, for: .tabBar)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.isSessionInProgress)
    }

    private var introduction: some View {
        VStack(spacing: 24) {
            HeroCard {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text(viewModel.selectedVerbID.capitalized)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .frame(height: 68)
                            .opacity(viewModel.isSelectedVerbReady ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeIn(duration: 0.25), value: viewModel.isSelectedVerbReady)
                        Button("Different verb", systemImage: "shuffle") {
                            viewModel.perform(.shuffleVerb)
                        }
                        .frame(minHeight: 48)
                        .disabled(!viewModel.isSelectedVerbReady)
                        Button {
                            viewModel.perform(.start(extra: false, mode: viewModel.preferredMode))
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.title.weight(.bold))
                                .frame(width: 76, height: 76)
                                .foregroundStyle(themeManager.current.heroBottom)
                                .background(.white, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start 20 questions about \(viewModel.selectedVerbID)")
                        .disabled(!viewModel.isSelectedVerbReady)
                    }
                    Picker("Learning mode", selection: Binding(
                        get: { viewModel.preferredMode }, set: { viewModel.selectMode($0) }
                    )) {
                        ForEach(LearningMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .frame(minHeight: 48)
                    Text("Practice one verb twenty times each day.")
                        .font(.footnote)
                        .opacity(0.8)
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                Label("Match the Spanish word to its English meaning.", systemImage: "character.bubble")
                Label("A correct first try earns one point.", systemImage: "checkmark.circle")
                Label("Tap a question to reveal it, without a point.", systemImage: "hand.tap")
            }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            Text("One daily session, plus one optional extra practice.\nYour place is saved after every answer.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private func question(_ session: TodaySession) -> some View {
        VStack(spacing: 22) {
            HStack {
                Label(session.isExtraPractice ? "Extra practice" : "Daily practice", systemImage: "sparkles")
                Spacer()
                Text("\(session.correctCount) / \(TodaySession.target)").monospacedDigit().bold()
            }.font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value: Double(session.correctCount), total: Double(TodaySession.target))
                .accessibilityLabel("\(session.correctCount) of \(TodaySession.target) correct answers")
            Button {
                viewModel.perform(.reveal(questionID: session.question.id))
            } label: {
                HeroCard {
                    VStack(spacing: 18) {
                        Text("QUESTION \(session.questionNumber)").font(.caption.weight(.bold)).tracking(2).opacity(0.7)
                        Text("\(session.question.person) · \(session.verbID) · \(session.question.tense.title)")
                            .font(.subheadline).opacity(0.8)
                        Text(session.question.spanish)
                            .font(.system(size: 68, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5).lineLimit(1)
                        Label(session.question.isRevealed ? "Answer revealed" : "Tap to reveal",
                              systemImage: session.question.isRevealed ? "eye.fill" : "hand.tap")
                            .font(.footnote).opacity(0.75)
                    }
                }
            }
            .buttonStyle(TodayButtonStyle())
            .disabled(session.question.isResolved)
            .accessibilityLabel("\(session.question.person) \(session.question.spanish), \(session.question.tense.title)")
            .accessibilityHint("Double tap to reveal the answer. Revealed answers earn no point.")

            if session.canChangeFocus {
                Picker("Learning mode", selection: Binding(get: { session.mode }, set: { viewModel.perform(.mode($0)) })) {
                    ForEach(LearningMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu).frame(minHeight: 48)
                Button("Different verb", systemImage: "shuffle") { viewModel.perform(.shuffleVerb) }
                    .frame(minHeight: 48)
                Text("Choose now. Your verb and mode lock at question two.").font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                ForEach(Array(session.question.choices.enumerated()), id: \.element) { index, answer in
                    answerButton(answer, index: index, question: session.question)
                }
            }
            Text(viewModel.feedback).font(.subheadline).multilineTextAlignment(.center)
                .foregroundStyle(.secondary).frame(minHeight: 42)
        }
    }

    private func answerButton(_ answer: String, index: Int, question: WordQuestion) -> some View {
        let isCorrect = question.isResolved && answer == question.answer
        let isWrong = question.wrongAnswers.contains(answer)
        let background = isCorrect ? themeManager.current.success : isWrong ? themeManager.current.error : themeManager.current.surface
        return Button {
            viewModel.perform(.answer(questionID: question.id, value: answer))
        } label: {
            HStack(spacing: 4) {
                Text(answer).font(.headline).multilineTextAlignment(.center)
                if isCorrect || isWrong {
                    Image(systemName: isCorrect ? "checkmark" : "xmark").font(.caption.bold())
                }
            }
            .lineLimit(nil).padding(.horizontal, 8).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 76)
            .foregroundStyle(isCorrect || isWrong ? Color.white : Color.primary)
            .background(background, in: RoundedRectangle(cornerRadius: index.isMultiple(of: 2) ? 30 : 24))
            .overlay(RoundedRectangle(cornerRadius: index.isMultiple(of: 2) ? 30 : 24)
                .strokeBorder(themeManager.current.tint.opacity(isCorrect || isWrong ? 0 : 0.18)))
            .padding(.top, index % 2 == 1 ? 7 : 0)
        }
        .buttonStyle(TodayButtonStyle())
        .disabled(question.isResolved || isWrong)
        .accessibilityLabel("\(answer)\(isCorrect ? ", correct answer" : isWrong ? ", incorrect answer" : "")")
    }

    private func completion(_ session: TodaySession) -> some View {
        VStack(spacing: 24) {
            HeroCard {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 92)).foregroundStyle(.mint)
                    Text(viewModel.isDayLocked ? "A brilliant day's work." : "Today's twenty. Done.")
                        .font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text("\(TodaySession.target) answers you knew.\nThat's something to feel good about.")
                        .multilineTextAlignment(.center).opacity(0.8)
                }
            }
            Label("\(viewModel.streak) day streak", systemImage: "flame.fill").font(.title2.bold()).foregroundStyle(.orange)
            if viewModel.canStartExtraPractice {
                PrimaryAction(title: "One more? Extra practice", symbol: "plus.circle") {
                    viewModel.perform(.start(extra: true, mode: session.mode))
                }
                Text("Optional: another \(TodaySession.target) correct answers. Your streak is already secured.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                Label("All done. Come back tomorrow.", systemImage: "moon.stars.fill").font(.headline)
                Text("Both sessions are complete. Practice unlocks at local midnight.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }
}
