import EfficientTimeCore
import SwiftUI

struct PlanSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var visibleMonth = LocalDate.today()
    @State private var copyTargetDate = LocalDate.today().adding(days: 1)
    @State private var copyVisibleMonth = LocalDate.today().adding(days: 1)
    @State private var pendingDeleteDate: LocalDate?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            datePickerSection
            Divider()
            weekOverview
            Divider()
            copyControls
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .onAppear {
            visibleMonth = monthStart(for: model.selectedDate)
            copyTargetDate = model.selectedDate.adding(days: 1)
            copyVisibleMonth = monthStart(for: copyTargetDate)
        }
        .onChange(of: model.selectedDateForPicker) { _, newValue in
            let selectedMonth = monthStart(for: model.selectedDate)
            if selectedMonth != visibleMonth {
                visibleMonth = selectedMonth
            }
            if copyTargetDate == localDate(from: newValue) {
                copyTargetDate = model.selectedDate.adding(days: 1)
                copyVisibleMonth = monthStart(for: copyTargetDate)
            }
        }
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button(model.tr("删除这一天计划"), role: .destructive) {
                if let pendingDeleteDate {
                    model.deletePlan(on: pendingDeleteDate)
                }
                pendingDeleteDate = nil
            }
            Button(model.tr("取消"), role: .cancel) {}
        } message: {
            Text(model.tr("该日期会从本周概览中移除。以后仍可通过日期选择器重新创建。"))
        }
    }

    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(model.tr("选择日期"), systemImage: "calendar")
                    .font(.headline)
                Spacer()
                statusBadge
            }

            HStack(spacing: 8) {
                Button {
                    model.selectPreviousDay()
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .help(model.tr("前一天"))

                VStack(spacing: 2) {
                    Text(model.selectedDateTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("\(model.todayPlan.date.displayString) \(model.weekdayTitle(for: model.todayPlan.date))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Button {
                    model.selectNextDay()
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .help(model.tr("后一天"))
            }

            PlanMonthCalendarView(
                selectedDate: model.selectedDate,
                visibleMonth: $visibleMonth,
                accentColor: model.settings.accentColor
            ) { date in
                model.selectDate(date)
            }

            HStack(spacing: 8) {
                Button(model.tr("今天")) {
                    model.selectToday()
                }
                .buttonStyle(.bordered)
                .tint(model.selectedDate == LocalDate.today() ? model.settings.accentColor : .secondary)

                Button(model.tr("明天")) {
                    model.selectTomorrow()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .controlSize(.small)
        }
    }

    private var statusBadge: some View {
        Text(model.planStatusTitle(model.todayPlan.status))
            .font(.caption)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(model.settings.accentColor)
            .background(model.settings.accentColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var weekOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.tr("本周概览"))
                .font(.subheadline)
                .fontWeight(.semibold)

            if model.weekSummaries.isEmpty {
                Text(model.tr("本周还没有保存的计划。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(model.weekSummaries) { summary in
                HStack(spacing: 6) {
                    Button {
                        model.selectDate(summary.date)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(model.weekdayTitle(for: summary.date)) \(summary.date.shortDisplayString)")
                                    .font(.caption)
                                    .fontWeight(summary.isSelected ? .semibold : .regular)
                                Text(model.planStatusTitle(summary.status))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(model.itemCountText(summary.taskCount))
                                .font(.caption)
                            Text("\(summary.plannedMinutes / 60)h\(summary.plannedMinutes % 60)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 54, alignment: .trailing)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            summary.isSelected
                            ? model.settings.accentColor.opacity(0.14)
                            : Color.secondary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        pendingDeleteDate = summary.date
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(model.canDeletePlan(on: summary.date) ? .red : .secondary.opacity(0.45))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!model.canDeletePlan(on: summary.date))
                    .help(model.tr("删除这一天计划"))
                }
            }
        }
    }

    private var copyControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(model.tr("复制当前计划"), systemImage: "doc.on.doc")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    model.copyCurrentPlan(to: copyTargetDate)
                } label: {
                    Label(model.tr("复制"), systemImage: "arrowshape.turn.up.forward")
                }
                .buttonStyle(.bordered)
                .disabled(copyTargetDate == model.selectedDate || !model.canDeletePlan(on: model.selectedDate))
            }

            HStack {
                Text(model.trf("目标：%@ %@", copyTargetDate.displayString, model.weekdayTitle(for: copyTargetDate)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            PlanMonthCalendarView(
                selectedDate: copyTargetDate,
                visibleMonth: $copyVisibleMonth,
                accentColor: model.settings.accentColor,
                isCompact: true
            ) { date in
                copyTargetDate = date
                copyVisibleMonth = monthStart(for: date)
            }
        }
    }

    private var deleteConfirmationTitle: String {
        guard let pendingDeleteDate else {
            return model.tr("确定删除计划吗？")
        }
        return model.trf("确定删除 %@ 的计划吗？", pendingDeleteDate.displayString)
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding {
            pendingDeleteDate != nil
        } set: { isPresented in
            if !isPresented {
                pendingDeleteDate = nil
            }
        }
    }

    private func localDate(from date: Date) -> LocalDate {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return LocalDate(
            year: components.year ?? model.selectedDate.year,
            month: components.month ?? model.selectedDate.month,
            day: components.day ?? model.selectedDate.day
        )
    }

    private func monthStart(for date: LocalDate) -> LocalDate {
        LocalDate(year: date.year, month: date.month, day: 1)
    }

}

struct PlanMonthCalendarView: View {
    var selectedDate: LocalDate
    @Binding var visibleMonth: LocalDate
    var accentColor: Color
    var isCompact = false
    var onSelect: (LocalDate) -> Void

    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: isCompact ? 5 : 8) {
            HStack(spacing: isCompact ? 4 : 6) {
                calendarButton("chevron.left.2") {
                    visibleMonth = adding(years: -1, to: visibleMonth)
                }
                .help(model.tr("上一年"))

                calendarButton("chevron.left") {
                    visibleMonth = adding(months: -1, to: visibleMonth)
                }
                .help(model.tr("上一月"))

                Spacer()

                Text(monthTitle)
                    .font(.system(size: isCompact ? 12 : 14, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Spacer()

                calendarButton("chevron.right") {
                    visibleMonth = adding(months: 1, to: visibleMonth)
                }
                .help(model.tr("下一月"))

                calendarButton("chevron.right.2") {
                    visibleMonth = adding(years: 1, to: visibleMonth)
                }
                .help(model.tr("下一年"))
            }

            LazyVGrid(columns: calendarColumns, spacing: isCompact ? 3 : 5) {
                ForEach(AppLocalization.shortWeekdayTitles(language: model.effectiveLanguage), id: \.self) { title in
                    Text(title)
                        .font(.system(size: isCompact ? 9 : 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(height: isCompact ? 14 : 18)
                }

                ForEach(Array(calendarCells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayButton(date)
                    } else {
                        Color.clear
                            .frame(height: dayHeight)
                    }
                }
            }
        }
        .padding(isCompact ? 7 : 10)
        .background(
            LinearGradient(
                colors: [
                    accentColor.opacity(isCompact ? 0.07 : 0.10),
                    Color.white.opacity(isCompact ? 0.34 : 0.46)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: isCompact ? 10 : 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: isCompact ? 10 : 14, style: .continuous)
                .stroke(accentColor.opacity(0.16), lineWidth: 1)
        }
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: isCompact ? 2 : 4), count: 7)
    }

    private var dayHeight: CGFloat {
        isCompact ? 23 : 30
    }

    private var calendarCells: [LocalDate?] {
        let firstDay = LocalDate(year: visibleMonth.year, month: visibleMonth.month, day: 1)
        let firstWeekday = Calendar.current.component(.weekday, from: firstDay.date())
        let leadingBlankCount = max(0, firstWeekday - 1)
        let dayCount = Calendar.current.range(of: .day, in: .month, for: firstDay.date())?.count ?? 31
        var cells = Array<LocalDate?>(repeating: nil, count: leadingBlankCount)
        cells.append(contentsOf: (1...dayCount).map { LocalDate(year: visibleMonth.year, month: visibleMonth.month, day: $0) })
        let remainder = cells.count % 7
        if remainder != 0 {
            cells.append(contentsOf: Array<LocalDate?>(repeating: nil, count: 7 - remainder))
        }
        return cells
    }

    private var monthTitle: String {
        model.trf("%d 年 %d 月", visibleMonth.year, visibleMonth.month)
    }

    private func calendarButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isCompact ? 9 : 10, weight: .bold))
                .frame(width: isCompact ? 21 : 24, height: isCompact ? 18 : 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: isCompact ? 6 : 7, style: .continuous))
    }

    private func dayButton(_ date: LocalDate) -> some View {
        let isSelected = date == selectedDate
        let isToday = date == LocalDate.today()
        return Button {
            onSelect(date)
        } label: {
            Text("\(date.day)")
                .font(.system(size: isCompact ? 10 : 12, weight: isSelected ? .bold : .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.white : (isToday ? accentColor : Color.primary))
                .frame(maxWidth: .infinity)
                .frame(height: dayHeight)
                .background(dayBackground(isSelected: isSelected, isToday: isToday))
                .overlay {
                    RoundedRectangle(cornerRadius: isCompact ? 7 : 9, style: .continuous)
                        .stroke(isToday && !isSelected ? accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func dayBackground(isSelected: Bool, isToday: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(accentColor)
        }
        if isToday {
            return AnyShapeStyle(accentColor.opacity(0.11))
        }
        return AnyShapeStyle(Color.white.opacity(0.28))
    }

    private func adding(months: Int, to date: LocalDate) -> LocalDate {
        adding(DateComponents(month: months), to: date)
    }

    private func adding(years: Int, to date: LocalDate) -> LocalDate {
        adding(DateComponents(year: years), to: date)
    }

    private func adding(_ components: DateComponents, to date: LocalDate) -> LocalDate {
        let nextDate = Calendar.current.date(byAdding: components, to: date.date()) ?? date.date()
        let nextComponents = Calendar.current.dateComponents([.year, .month, .day], from: nextDate)
        return LocalDate(
            year: nextComponents.year ?? date.year,
            month: nextComponents.month ?? date.month,
            day: 1
        )
    }
}

#Preview {
    PlanSettingsView()
        .environmentObject(AppModel())
}
