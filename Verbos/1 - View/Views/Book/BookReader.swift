import SwiftUI

// This stateless view renders book content supplied by the Library feature.
struct BookReader: View {
    let book: LearningBook
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DailyBookCover(book: book)
                .frame(width: 190, height: 280)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(book.englishTitle).font(.title3).foregroundStyle(.secondary)
            Text("By \(book.author)").font(.subheadline)
            ForEach(book.fullText) { sentence in
                VStack(alignment: .leading, spacing: 10) {
                    Text(sentence.spanish).font(.title3)
                    Text(sentence.english).foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeManager.current.surface, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}

// A book-cover treatment makes the daily reading selection feel like a story to enter.
struct DailyBookCover: View {
    let book: LearningBook
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [themeManager.current.heroTop, themeManager.current.heroBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 36)
                .frame(width: 190, height: 190)
                .offset(x: 95, y: 88)
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 12) {
                Text("VERBOS / DAILY BOOK")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .opacity(0.75)
                Text(book.title)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 62, weight: .ultraLight))
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                Text(book.author.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .opacity(0.75)
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: themeManager.current.tint.opacity(0.2), radius: 14, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cover of \(book.title), by \(book.author)")
    }
}
