import SwiftUI
import SwiftData

// MARK: - ANA ÇATI
struct ContentView: View {
    var body: some View {
        TabView {
            HabitListView()
                .tabItem { Label("Alışkanlıklar", systemImage: "list.bullet.clipboard") }
            StatisticsView()
                .tabItem { Label("Durum Analizi", systemImage: "chart.pie.fill") }
        }
    }
}

// MARK: - 1. Sekme: LİSTE GÖRÜNÜMÜ
struct HabitListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.creationDate, order: .forward) private var habits: [Habit]
    
    @State private var showingAddHabit = false
    @State private var habitToEdit: Habit?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if habits.isEmpty {
                    ContentUnavailableView("Hedef Yok", systemImage: "target", description: Text("Sağ üstteki + butonuna bas."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(habits) { habit in
                                HabitCardView(habit: habit)
                                    .contextMenu {
                                        Button { habitToEdit = habit } label: { Label("Düzenle", systemImage: "pencil") }
                                        Button(role: .destructive) { deleteHabit(habit) } label: { Label("Sil", systemImage: "trash") }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Planlayıcı 🗓️")
            .toolbar {
                Button(action: { showingAddHabit = true }) {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
            }
            .sheet(isPresented: $showingAddHabit) { AddHabitView(isPresented: $showingAddHabit) }
            .sheet(item: $habitToEdit) { habit in EditHabitView(habit: habit) }
        }
    }
    
    private func deleteHabit(_ habit: Habit) {
        withAnimation { modelContext.delete(habit) }
    }
}

// MARK: - 2. Sekme: İSTATİSTİK (GARANTİ HESAPLAMA)
struct StatisticsView: View {
    @Query(sort: \Habit.creationDate) private var habits: [Habit]
    
    // Hesaplanan yüzdeleri tutan basit bir sözlük
    @State private var percentages: [UUID: Double] = [:]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if habits.isEmpty {
                    ContentUnavailableView("Veri Yok", systemImage: "chart.bar", description: Text("İstatistik için önce hedef ekle."))
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(habits) { habit in
                                // Kartın içine hesaplanmış yüzdeyi gönderiyoruz
                                StatCard(habit: habit, percentage: percentages[habit.id] ?? 0.0)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Performans 📊")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: calculateStats) {
                        HStack {
                            Text("Güncelle")
                            Image(systemName: "arrow.clockwise")
                        }
                        .font(.headline)
                        .foregroundStyle(Color.blue)
                    }
                }
            }
            .onAppear {
                // Sayfa açıldığında da hesapla
                calculateStats()
            }
        }
    }
    
    // --- İŞTE DÜZELTİLMİŞ MATEMATİK ---
    func calculateStats() {
        // Titreşim ver ki bastığını hisset
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        var newPercentages: [UUID: Double] = [:]
        let calendar = Calendar.current
        let today = Date() // Şu an
        
        for habit in habits {
            // Başlangıç tarihini saat 00:00'a çek (Hata payını yok et)
            let startDate = calendar.startOfDay(for: habit.creationDate)
            let endDate = calendar.startOfDay(for: today)
            
            // Başlangıçtan bugüne kaç gün geçmiş?
            let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            
            var required = 0.0 // Yapılması gereken gün sayısı
            var completed = 0.0 // Yapılan gün sayısı
            
            // Döngü ile her günü kontrol et
            for i in 0...totalDays {
                if let dateToCheck = calendar.date(byAdding: .day, value: i, to: startDate) {
                    
                    // 1. Bu tarihte bu görev yapılmalı mıydı? (Pzt, Salı vb. kontrolü)
                    if habit.isDue(on: dateToCheck) {
                        required += 1
                        
                        // 2. Peki yapılmış mı?
                        if habit.isCompleted(on: dateToCheck) {
                            completed += 1
                        }
                    }
                }
            }
            
            // Matematik: (Yapılan / Gereken)
            if required > 0 {
                newPercentages[habit.id] = completed / required
            } else {
                newPercentages[habit.id] = 0.0
            }
        }
        
        // Sonuçları ekrana bas
        self.percentages = newPercentages
    }
}

// MARK: - İstatistik Kartı
struct StatCard: View {
    var habit: Habit
    var percentage: Double // Dışarıdan hazır gelen veri
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading) {
                    Text(habit.title).font(.headline).bold()
                    Text("Başlangıç: \(formatDate(habit.creationDate))").font(.caption).foregroundStyle(Color.secondary)
                }
                Spacer()
                Text(habit.frequency.rawValue)
                    .font(.caption2.bold())
                    .padding(6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(Color.blue)
                    .cornerRadius(6)
            }
            Divider()
            HStack(spacing: 15) {
                StatCircle(title: "Gerçekleşme", percentage: percentage)
                
                // Sağ tarafa açıklayıcı metin
                VStack(alignment: .leading, spacing: 5) {
                    Text("Durum:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(percentageText(percentage))
                        .font(.headline)
                        .foregroundStyle(percentageColor(percentage))
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    func percentageText(_ val: Double) -> String {
        if val >= 1.0 { return "Kusursuz!" }
        if val >= 0.8 { return "Harika" }
        if val >= 0.5 { return "İyi Gidiyor" }
        if val > 0 { return "Devam Et" }
        return "Henüz Başlamadın"
    }
    
    func percentageColor(_ val: Double) -> Color {
        if val >= 0.5 { return .green }
        if val > 0 { return .orange }
        return .red
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct StatCircle: View {
    var title: String
    var percentage: Double
    
    var body: some View {
        ZStack {
            Circle().stroke(lineWidth: 8).opacity(0.1).foregroundColor(Color.blue)
            Circle()
                .trim(from: 0.0, to: CGFloat(percentage))
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .foregroundColor(percentage < 0.5 ? Color.orange : Color.green)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.spring, value: percentage) // Animasyon eklendi
            Text(String(format: "%%%d", Int(percentage * 100)))
                .font(.system(.title3, design: .rounded).bold())
        }
        .frame(width: 70, height: 70)
    }
}

// MARK: - Ekleme Ekranı
struct AddHabitView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var selectedFrequency: Frequency = .daily
    @State private var selectedWeekdays: Set<Int> = []
    
    let weekdays = [(2, "Pzt"), (3, "Sal"), (4, "Çar"), (5, "Per"), (6, "Cum"), (7, "Cmt"), (1, "Paz")]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Hedefin Adı") { TextField("Örn: Kitap Oku", text: $title) }
                Section("Sıklık") {
                    Picker("Tekrar", selection: $selectedFrequency) {
                        ForEach(Frequency.allCases, id: \.self) { freq in Text(freq.rawValue).tag(freq) }
                    }.pickerStyle(.segmented)
                    
                    if selectedFrequency == .weekly {
                        HStack {
                            ForEach(weekdays, id: \.0) { day in
                                Button(action: {
                                    if selectedWeekdays.contains(day.0) { selectedWeekdays.remove(day.0) }
                                    else { selectedWeekdays.insert(day.0) }
                                }) {
                                    Text(day.1).font(.caption2.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
                                        .background(selectedWeekdays.contains(day.0) ? Color.blue : Color.gray.opacity(0.1))
                                        .foregroundStyle(selectedWeekdays.contains(day.0) ? Color.white : Color.primary)
                                        .cornerRadius(8)
                                }.buttonStyle(.plain)
                            }
                        }.padding(.vertical, 5)
                    }
                }
            }
            .navigationTitle("Yeni Hedef")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        let newHabit = Habit(title: title, frequency: selectedFrequency, selectedWeekdays: Array(selectedWeekdays), targetDayNumber: Calendar.current.component(.day, from: Date()), targetMonthNumber: Calendar.current.component(.month, from: Date()))
                        modelContext.insert(newHabit)
                        isPresented = false
                    }
                    .disabled(title.isEmpty || (selectedFrequency == .weekly && selectedWeekdays.isEmpty))
                }
            }
        }
    }
}

// MARK: - Düzenleme Ekranı
struct EditHabitView: View {
    @Bindable var habit: Habit
    @Environment(\.dismiss) var dismiss
    let weekdays = [(2, "Pzt"), (3, "Sal"), (4, "Çar"), (5, "Per"), (6, "Cum"), (7, "Cmt"), (1, "Paz")]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Hedefin Adı") { TextField("Başlık", text: $habit.title) }
                Section("Sıklık (Değiştirilemez)") { Text(habit.frequency.rawValue).foregroundStyle(Color.secondary) }
                if habit.frequency == .weekly {
                    Section("Günleri Düzenle") {
                        HStack {
                            ForEach(weekdays, id: \.0) { day in
                                Button(action: {
                                    if habit.selectedWeekdays.contains(day.0) {
                                        if let index = habit.selectedWeekdays.firstIndex(of: day.0) { habit.selectedWeekdays.remove(at: index) }
                                    } else { habit.selectedWeekdays.append(day.0) }
                                }) {
                                    Text(day.1).font(.caption2.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
                                        .background(habit.selectedWeekdays.contains(day.0) ? Color.blue : Color.gray.opacity(0.1))
                                        .foregroundStyle(habit.selectedWeekdays.contains(day.0) ? Color.white : Color.primary)
                                        .cornerRadius(8)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Düzenle")
            .toolbar { Button("Bitti") { dismiss() } }
        }
    }
}

// MARK: - Kart ve Yuvarlak Görünümleri
struct HabitCardView: View {
    var habit: Habit
    let daysToShow = 7
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(habit.title).font(.headline).fontWeight(.bold)
                    Text(habit.frequency.rawValue).font(.caption2).foregroundStyle(Color.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.orange)
                    Text("\(habit.currentStreak)").font(.title3).fontWeight(.heavy).foregroundStyle(Color.orange)
                }
            }
            Divider()
            HStack(spacing: 0) {
                ForEach(0..<daysToShow, id: \.self) { index in
                    let date = Calendar.current.date(byAdding: .day, value: -((daysToShow - 1) - index), to: Date())!
                    DayCircleView(date: date, habit: habit).frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
    }
}

struct DayCircleView: View {
    let date: Date
    var habit: Habit
    var isCompleted: Bool { habit.isCompleted(on: date) }
    var isDue: Bool { habit.isDue(on: date) }
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(dayName(for: date)).font(.caption2).foregroundStyle(isDue ? Color.secondary : Color.gray.opacity(0.4))
            Button(action: toggleDate) {
                ZStack {
                    Circle().fill(bgColor).frame(width: 36, height: 36)
                    if isCompleted { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(Color.white) }
                    else if !isDue { Circle().fill(Color.gray.opacity(0.3)).frame(width: 6, height: 6) }
                    if isToday && isDue && !isCompleted { Circle().strokeBorder(Color.blue.opacity(0.5), lineWidth: 2).frame(width: 36, height: 36) }
                }
            }.disabled(!isDue && !isCompleted).buttonStyle(.plain)
        }
    }
    
    var bgColor: Color {
        if isCompleted { return isToday ? Color.blue : Color.green }
        if !isDue { return Color.clear }
        return Color.gray.opacity(0.1)
    }
    
    func toggleDate() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation {
            if isCompleted { habit.completedDates.removeAll { Calendar.current.isDate($0, inSameDayAs: date) } }
            else { habit.completedDates.append(date) }
        }
    }
    
    func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "EE"
        return formatter.string(from: date)
    }
}
