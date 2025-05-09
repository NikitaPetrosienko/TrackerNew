
import CoreData
import UIKit

final class TrackerCategoryStore: NSObject {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    
    // MARK: - Init
    
    convenience override init() {
        let context = PersistentContainer.shared.viewContext
        self.init(context: context)
        print("\(#file):\(#line)] \(#function) TrackerCategoryStore инициализирован с дефолтным контекстом")
    }
    
    init(context: NSManagedObjectContext) {
        self.context = context
        super.init()
        print("\(#file):\(#line)] \(#function) TrackerCategoryStore инициализирован с переданным контекстом")
    }
    
    // MARK: - Methods
    
    func createCategory(_ category: TrackerCategory) throws {
        let categoryCoreData = TrackerCategoryCoreData(context: context)
        categoryCoreData.title = category.title
        
        do {
            try context.save()
            print("\(#file):\(#line)] \(#function) Сохранена категория: \(category.title)")
        } catch {
            print("\(#file):\(#line)] \(#function) Ошибка сохранения категории: \(error)")
            throw error
        }
    }
    
    func fetchCategories() throws -> [TrackerCategory] {
        let request = TrackerCategoryCoreData.fetchRequest()
        
        do {
            let categoriesCoreData = try context.fetch(request)
            return try categoriesCoreData.map { try category(from: $0) }
        } catch {
            print("\(#file):\(#line)] \(#function) Ошибка загрузки категорий: \(error)")
            throw error
        }
    }
    
    private func category(from categoryCoreData: TrackerCategoryCoreData) throws -> TrackerCategory {
        guard let title = categoryCoreData.title else {
            throw TrackerCategoryStoreError.decodingErrorInvalidData
        }
        
        return TrackerCategory(
            title: title,
            trackers: [] // нужно будет добавить связь с трекерами
        )
    }
}

// MARK: - Errors

enum TrackerCategoryStoreError: Error {
    case decodingErrorInvalidData
}
