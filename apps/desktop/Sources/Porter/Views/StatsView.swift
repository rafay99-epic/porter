import SwiftUI
import Charts
import PorterCore

/// Stats dashboard: how much Porter has filed over time, by category, and how
/// much space it moved. Reads the persisted history (`StatsStore`) so it shows
/// trends across launches, not just this session.
struct StatsView: View {
    let coordinator: SortCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var records: [StatRecord]?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            HStack {
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(14)
        }
        .frame(width: 540, height: 600)
        .task { records = await coordinator.loadStats() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis").font(.title3).foregroundStyle(.tint)
            Text("Statistics").font(.headline)
            Spacer()
        }
        .padding(14)
    }

    @ViewBuilder private var content: some View {
        if let records {
            if records.isEmpty {
                emptyState
            } else {
                ScrollView { dashboard(records).padding(16) }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar").font(.system(size: 30)).foregroundStyle(.tertiary)
            Text("No history yet").font(.callout).foregroundStyle(.secondary)
            Text("Once Porter sorts some files, your stats appear here.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dashboard(_ records: [StatRecord]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            summaryCards(records)
            perDayChart(records)
            byCategoryChart(records)
        }
    }

    // MARK: - Summary cards

    private func summaryCards(_ records: [StatRecord]) -> some View {
        let totalBytes = records.reduce(Int64(0)) { $0 + $1.bytes }
        let categories = Set(records.map(\.category)).count
        return HStack(spacing: 12) {
            statCard(value: "\(records.count)", label: "files sorted", icon: "doc.on.doc")
            statCard(value: ByteSize.format(totalBytes), label: "space moved", icon: "externaldrive")
            statCard(value: "\(categories)", label: "categories", icon: "folder")
        }
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).foregroundStyle(.tint)
            Text(value).font(.title2).bold().lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Charts

    private func perDayChart(_ records: [StatRecord]) -> some View {
        let days = perDayCounts(records, lastDays: 30)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Files sorted — last 30 days").font(.subheadline).bold()
            Chart(days) { day in
                BarMark(x: .value("Day", day.day, unit: .day),
                        y: .value("Files", day.count))
                .foregroundStyle(.tint)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) }
            .frame(height: 180)
        }
    }

    private func byCategoryChart(_ records: [StatRecord]) -> some View {
        let cats = categoryCounts(records)
        return VStack(alignment: .leading, spacing: 6) {
            Text("By category").font(.subheadline).bold()
            Chart(cats) { cat in
                BarMark(x: .value("Files", cat.count),
                        y: .value("Category", cat.category))
                .foregroundStyle(.tint)
                .annotation(position: .trailing) {
                    Text("\(cat.count)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(height: CGFloat(max(1, cats.count)) * 30 + 20)
        }
    }

    // MARK: - Aggregation

    private struct DayCount: Identifiable { let day: Date; let count: Int; var id: Date { day } }
    private struct CategoryCount: Identifiable { let category: String; let count: Int; var id: String { category } }

    /// Counts per calendar day for the last `lastDays`, including zero-days so the
    /// axis is continuous.
    private func perDayCounts(_ records: [StatRecord], lastDays: Int) -> [DayCount] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var counts: [Date: Int] = [:]
        for record in records {
            let day = cal.startOfDay(for: record.date)
            counts[day, default: 0] += 1
        }
        return (0..<lastDays).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayCount(day: day, count: counts[day] ?? 0)
        }
    }

    /// File counts per category, most files first.
    private func categoryCounts(_ records: [StatRecord]) -> [CategoryCount] {
        var counts: [String: Int] = [:]
        for record in records { counts[record.category, default: 0] += 1 }
        return counts.map { CategoryCount(category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}
