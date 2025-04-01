
import CoreData
import UIKit

final class TrackerCoreStore: TrackerStoreProtocol {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    
    // MARK: - Init
    
    init(context: NSManagedObjectContext = PersistentContainer.shared.viewContext) {
           self.context = context
       }
    
    // MARK: - Methods
    
    func createTracker(_ tracker: Tracker, category: TrackerCategory) throws {
        let trackerCoreData = TrackerCoreData(context: context)
        trackerCoreData.id = tracker.id
        trackerCoreData.title = tracker.title
        trackerCoreData.color = tracker.color.toHex()
        trackerCoreData.emoji = tracker.emoji
        trackerCoreData.schedule = Int64(tracker.schedule.reduce(0) { result, weekDay in
            result | (1 << (weekDay.rawValue - 1))
        })
        trackerCoreData.isPinned = tracker.isPinned
        trackerCoreData.creationDate = tracker.creationDate
        
        do {
            try context.save()
            print("\(#file):\(#line)] \(#function) Сохранён трекер: \(tracker.title)")
        } catch {
            print("\(#file):\(#line)] \(#function) Ошибка сохранения трекера: \(error)")
            throw error
        }
    }
    
    func fetchTrackers() throws -> [Tracker] {
          let request = TrackerCoreData.fetchRequest()
          return try context.fetch(request).map { try tracker(from: $0) }
      }
    
    // MARK: - Private methods
    
    func tracker(from trackerCoreData: TrackerCoreData) throws -> Tracker {
        guard let id = trackerCoreData.id,
              let title = trackerCoreData.title,
              let colorHex = trackerCoreData.color,
              let emoji = trackerCoreData.emoji,
              let color = UIColor(hex: colorHex) else {
            throw TrackerStoreError.decodingErrorInvalidData
        }
        
        return Tracker(
            id: id,
            title: title,
            color: color,
            emoji: emoji,
            schedule: WeekDay.decode(from: trackerCoreData.schedule),
            isPinned: trackerCoreData.isPinned,
            creationDate: trackerCoreData.creationDate
        )
    }
    
    func countTrackers() -> Int {
        let fetchRequest: NSFetchRequest<TrackerCoreData> = TrackerCoreData.fetchRequest()
        
        do {
            let count = try context.count(for: fetchRequest)
            print("Количество трекеров в базе данных: \(count)")
            return count
        } catch {
            print("\(#file):\(#line)] \(#function) Ошибка подсчета трекеров в базе: \(error)")
            return 0
        }
    }
    
    func deleteTracker(id: UUID) throws {
           let fetchRequest: NSFetchRequest<TrackerCoreData> = TrackerCoreData.fetchRequest()
           fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
              
           do {
               let trackers = try context.fetch(fetchRequest)
               if let trackerToDelete = trackers.first {
                   context.delete(trackerToDelete)
                   try context.save()
                   print("\(#file):\(#line)] \(#function) Трекер успешно удалён из CoreData: \(id)")
               } else {
                   print("\(#file):\(#line)] \(#function) Трекер не найден в CoreData: \(id)")
               }
           } catch {
               print("\(#file):\(#line)] \(#function) Ошибка при удалении трекера: \(error)")
               throw error
           }
       }
   }

// MARK: - Errors

enum TrackerStoreError: Error {
    case decodingErrorInvalidData
}
