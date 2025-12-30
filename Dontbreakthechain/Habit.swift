import Foundation
import SwiftData

// Sıklık Türleri
enum Frequency: String, Codable, CaseIterable {
    case daily = "Her Gün"
    case weekly = "Haftanın Günleri"
    case monthly = "Ayda Bir (Bugün)"
    case yearly = "Yılda Bir (Bugün)"
}

@Model
final class Habit {
    var id: UUID
    var title: String
    var completedDates: [Date]
    var creationDate: Date
    
    // YENİ EKLENEN ALANLAR
    var frequencyRaw: String = Frequency.daily.rawValue
    var selectedWeekdays: [Int] = [] // 1=Pazar, 2=Pzt... (Haftalık için)
    var targetDayNumber: Int? // Ayın kaçıncı günü? (Aylık için)
    var targetMonthNumber: Int? // Hangi ay? (Yıllık için)
    
    init(title: String, frequency: Frequency = .daily, selectedWeekdays: [Int] = [], targetDayNumber: Int? = nil, targetMonthNumber: Int? = nil) {
        self.id = UUID()
        self.title = title
        self.creationDate = Date()
        self.completedDates = []
        self.frequencyRaw = frequency.rawValue
        self.selectedWeekdays = selectedWeekdays
        self.targetDayNumber = targetDayNumber
        self.targetMonthNumber = targetMonthNumber
    }
    
    // Enum Çeviricisi
    var frequency: Frequency {
        get { Frequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }
    
    // Bir tarihte bu alışkanlık yapılmalı mı?
    func isDue(on date: Date) -> Bool {
        let calendar = Calendar.current
        
        switch frequency {
        case .daily:
            return true
            
        case .weekly:
            let weekday = calendar.component(.weekday, from: date)
            return selectedWeekdays.contains(weekday)
            
        case .monthly:
            guard let targetDay = targetDayNumber else { return false }
            let dayComponent = calendar.component(.day, from: date)
            return dayComponent == targetDay
            
        case .yearly:
            guard let targetDay = targetDayNumber, let targetMonth = targetMonthNumber else { return false }
            let components = calendar.dateComponents([.day, .month], from: date)
            return components.day == targetDay && components.month == targetMonth
        }
    }
    
    // O tarihte tamamlandı mı?
    func isCompleted(on date: Date) -> Bool {
        let calendar = Calendar.current
        return completedDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }
    
    // ZİNCİR HESAPLAMA (Sadece sorumlu olduğun günleri sayar)
    var currentStreak: Int {
        var streak = 0
        let calendar = Calendar.current
        var checkDate = Date()
        
        // Bugün sorumlu değilsek veya henüz yapmadıysak dünden başla
        if !isDue(on: checkDate) || !isCompleted(on: checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        
        // Geriye doğru 365 gün kontrol et (Sonsuz döngüyü önlemek için sınır)
        for _ in 0..<365 {
            if isDue(on: checkDate) {
                if isCompleted(on: checkDate) {
                    streak += 1
                } else {
                    // Sorumlu olduğun bir günü yapmamışsın, zincir koptu
                    break
                }
            }
            // Sorumlu olmadığın günleri atla, zinciri kırma
            guard let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDay
        }
        
        return streak
    }
}
