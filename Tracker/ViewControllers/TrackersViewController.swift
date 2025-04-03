
import UIKit
import CoreData

final class TrackersViewController: UIViewController {
    
    // MARK: - Properties
    
    // NSFetchedResultsController для автоматического отслеживания изменений в Core Data
    private var fetchedResultsController: NSFetchedResultsController<TrackerCoreData>!
    
    let layoutParams = LayoutParams()
    var filteredCategories: [TrackerCategory] = []
    var categories: [TrackerCategory] = []
    var currentDate: Date = Date()
    var completedTrackers: Set<CompletedTrackerID> = []
    
    // Используем общий экземпляр TrackerStore (TrackerStore.shared – настроен как синглтон)
    private let trackerStore: TrackerStoreProtocol = TrackerStore.shared
    private let trackerRecordStore = TrackerRecordStore()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        formatter.locale = Locale(identifier: "ru")
        return formatter
    }()
    
    struct LayoutParams {
        let columnCount: Int = 2
        let interItemSpacing: CGFloat = 9
        let leftInset: CGFloat = 16
        let rightInset: CGFloat = 16
        
        var totalInsetWidth: CGFloat {
            leftInset + rightInset + interItemSpacing * (CGFloat(columnCount) - 1)
        }
    }
    
    // MARK: - UI Elements
    
    private lazy var addButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "plusButton"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Трекеры"
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Поиск"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.backgroundImage = UIImage()
        searchBar.backgroundColor = .clear
        searchBar.tintColor = .black
        return searchBar
    }()
    
    private lazy var placeholderStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true
        return stack
    }()
    
    private lazy var placeholderImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "trackerPlaceholder")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Что будем отслеживать?"
        label.textColor = .label
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.preferredDatePickerStyle = .compact
        picker.datePickerMode = .date
        picker.locale = Locale(identifier: "ru_RU")
        picker.calendar.firstWeekday = 2
        picker.widthAnchor.constraint(equalToConstant: 120).isActive = true
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.addTarget(self, action: #selector(datePickerValueChanged), for: .valueChanged)
        picker.tintColor = .blue
        
        if let textLabel = picker.subviews.first?.subviews.first as? UILabel {
            textLabel.font = .systemFont(ofSize: 17)
        }
        return picker
    }()
    
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.headerReferenceSize = CGSize(width: UIScreen.main.bounds.width, height: 50)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        collectionView.register(TrackerCell.self, forCellWithReuseIdentifier: TrackerCell.identifier)
        collectionView.register(
            SupplementaryView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "header"
        )
        collectionView.register(
            SupplementaryView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: "footer"
        )
        return collectionView
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupNavigationBar()
        setupPlaceholder()
        setupCollectionView()
        setupFetchedResultsController() // Настраиваем NSFetchedResultsController для автоматических обновлений
        loadTrackersFromStore()          // Загружаем данные из Core Data через fetchedResultsController
        loadTrackerRecords()
    }
    
    // MARK: - Setup Methods
    
    private func setupViews() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(titleLabel)
        view.addSubview(searchBar)
        placeholderStack.addArrangedSubview(placeholderImageView)
        placeholderStack.addArrangedSubview(placeholderLabel)
        view.addSubview(placeholderStack)
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            
            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 7),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        let addButton = UIButton(frame: CGRect(x: 6, y: 0, width: 42, height: 42))
        addButton.setImage(UIImage(named: "plusButton"), for: .normal)
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        let addBarButton = UIBarButtonItem(customView: addButton)
        let dateBarButton = UIBarButtonItem(customView: datePicker)
        navigationItem.leftBarButtonItem = addBarButton
        navigationItem.rightBarButtonItem = dateBarButton
    }
    
    private func setupPlaceholder() {
        placeholderStack.isHidden = false
        
        NSLayoutConstraint.activate([
            placeholderStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeholderStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            placeholderImageView.widthAnchor.constraint(equalToConstant: 80),
            placeholderImageView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    private func setupCollectionView() {
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // Новый метод для настройки NSFetchedResultsController
    private func setupFetchedResultsController() {
        let fetchRequest: NSFetchRequest<TrackerCoreData> = TrackerCoreData.fetchRequest()
        // Пример сортировки по дате создания
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: PersistentContainer.shared.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Ошибка при выполнении fetch: \(error)")
        }
    }
    
    // Обновление данных через fetchedResultsController
    private func loadTrackersFromStore() {
        guard let trackerCoreDatas = fetchedResultsController.fetchedObjects else { return }
        
        do {
            let loadedTrackers = try trackerCoreDatas.map { coreData -> Tracker in
                // Преобразуем объект Core Data в модель Tracker.
                // Метод tracker(from:) теперь имеет internal уровень доступа.
                return try (trackerStore as! TrackerCoreStore).tracker(from: coreData)
            }
            
            // Группировка трекеров в категории (на данный момент фиксированно "Важное")
            var categoriesDict: [String: [Tracker]] = [:]
            for tracker in loadedTrackers {
                let categoryTitle = "Важное" // Здесь можно добавить более сложную логику категорий
                categoriesDict[categoryTitle, default: []].append(tracker)
            }
            categories = categoriesDict.map { TrackerCategory(title: $0.key, trackers: $0.value) }
            filteredCategories = filterTrackersByDate(currentDate)
            
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                self.updatePlaceholderVisibility()
            }
        } catch {
            print("Ошибка преобразования объектов трекера: \(error)")
        }
    }
    
    private func filterTrackersByDate(_ date: Date) -> [TrackerCategory] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let adjustedWeekday = WeekDay(rawValue: weekday == 1 ? 7 : weekday - 1) ?? .monday
        
        let filteredCategories = categories.compactMap { category in
            let filteredTrackers = category.trackers.filter { tracker in
                let isIrregularEvent = tracker.schedule.count == 1 && tracker.creationDate != nil
                if isIrregularEvent {
                    let isCompletedInAnyDay = completedTrackers.contains { completedID in
                        completedID.id == tracker.id
                    }
                    if isCompletedInAnyDay {
                        let isCompletedOnThisDay = completedTrackers.contains { completedID in
                            completedID.id == tracker.id && calendar.isDate(completedID.date, inSameDayAs: date)
                        }
                        return isCompletedOnThisDay
                    } else {
                        return true
                    }
                } else {
                    let isScheduledForToday = tracker.schedule.contains(adjustedWeekday)
                    return isScheduledForToday
                }
            }
            return filteredTrackers.isEmpty ? nil : TrackerCategory(title: category.title, trackers: filteredTrackers)
        }
        return filteredCategories
    }
    
    private func loadTrackerRecords() {
        do {
            let records = try trackerRecordStore.fetchRecords()
            completedTrackers = Set(records.map { CompletedTrackerID(id: $0.id, date: $0.date) })
        } catch {
            print("Ошибка загрузки записей трекеров: \(error)")
        }
    }
    
    // MARK: - Actions
    
    @objc private func addButtonTapped() {
        let newTrackerController = NewTrackerController()
        newTrackerController.delegate = self
        let navigationController = UINavigationController(rootViewController: newTrackerController)
        navigationController.modalPresentationStyle = .automatic
        present(navigationController, animated: true)
    }
    
    @objc private func datePickerValueChanged(_ sender: UIDatePicker) {
        currentDate = sender.date
        let formattedDate = dateFormatter.string(from: sender.date)
        print("Выбрана дата: \(formattedDate)")
        
        filteredCategories = filterTrackersByDate(currentDate)
        collectionView.reloadData()
        updatePlaceholderVisibility()
    }
    
    // Обновление видимости placeholder в зависимости от наличия трекеров
    private func updatePlaceholderVisibility() {
        let hasVisibleTrackers = !filteredCategories.isEmpty
        
        placeholderStack.isHidden = hasVisibleTrackers
        collectionView.isHidden = !hasVisibleTrackers
        print("Всего категорий: \(categories.count), Видимых категорий: \(filteredCategories.count)")
    }
    
    // MARK: - TrackerManagement
    
    func isTrackerCompleted(_ tracker: Tracker, date: Date) -> Bool {
        let completedID = CompletedTrackerID(id: tracker.id, date: date)
        return completedTrackers.contains(completedID)
    }
    
    func addTrackerRecord(_ tracker: Tracker, date: Date) {
        let completedID = CompletedTrackerID(id: tracker.id, date: date)
        completedTrackers.insert(completedID)
        do {
            let record = TrackerRecord(id: tracker.id, date: date)
            try trackerRecordStore.addNewRecord(record)
        } catch {
            print("Ошибка сохранения записи трекера: \(error)")
        }
        collectionView.reloadData()
    }
    
    func removeTrackerRecord(_ tracker: Tracker, date: Date) {
        let completedID = CompletedTrackerID(id: tracker.id, date: date)
        do {
            try trackerRecordStore.deleteRecord(id: tracker.id, date: date)
            completedTrackers.remove(completedID)
            collectionView.reloadData()
        } catch {
            print("Ошибка удаления записи трекера: \(error)")
        }
    }
    
    func countCompletedDays(for tracker: Tracker) -> Int {
        completedTrackers.filter { $0.id == tracker.id }.count
    }
    
    func createCategory(withTitle title: String) {
        let newCategory = TrackerCategory(title: title, trackers: [])
        categories.append(newCategory)
        filteredCategories = filterTrackersByDate(currentDate)
        
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.updatePlaceholderVisibility()
            print("Добавлена новая категория: \(title)")
        }
    }
    
    struct CompletedTrackerID: Hashable {
        let id: UUID
        let date: Date
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(Calendar.current.startOfDay(for: date))
        }
        
        static func == (lhs: CompletedTrackerID, rhs: CompletedTrackerID) -> Bool {
            return lhs.id == rhs.id &&
                Calendar.current.isDate(lhs.date, inSameDayAs: rhs.date)
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension TrackersViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("NSFetchedResultsController: база обновилась")
        loadTrackersFromStore()
    }
}

// MARK: - UICollectionViewDelegate

extension TrackersViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("Выделена ячейка: \(indexPath.item)")
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] suggestedActions in
            let pinAction = UIAction(title: "Закрепить", image: UIImage(systemName: "pin")) { [weak self] _ in
                print("Закрепить трекер")
            }
            
            let editAction = UIAction(title: "Редактировать", image: UIImage(systemName: "pencil")) { [weak self] _ in
                print("Редактировать трекер")
            }
            
            let deleteAction = UIAction(
                title: "Удалить",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                guard let self = self else { return }
                let alert = UIAlertController(
                    title: "Удалить трекер?",
                    message: "Эта операция не может быть отменена",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Отменить", style: .cancel))
                alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
                    self?.deleteTracker(at: indexPath)
                })
                self.present(alert, animated: true)
            }
            return UIMenu(title: "", children: [pinAction, editAction, deleteAction])
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        print("Снято выделение с ячейки: \(indexPath.item)")
    }
}

// MARK: - NewHabitControllerDelegate

extension TrackersViewController: NewHabitControllerDelegate {
    func didCreateTracker(_ tracker: Tracker, category: String) {
        // Не нужно вручную обновлять массивы, так как NSFetchedResultsController
        // автоматически обновит список трекеров после сохранения в Core Data.
        // Можно оставить здесь только, например, перезагрузку коллекции, если это необходимо.
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
}

extension TrackersViewController {
    func addTracker(_ tracker: Tracker, to categoryTitle: String) {
        var newCategories = categories
        if let categoryIndex = categories.firstIndex(where: { $0.title == categoryTitle }) {
            let existingCategory = categories[categoryIndex]
            let newTrackers = existingCategory.trackers + [tracker]
            let updatedCategory = TrackerCategory(title: categoryTitle, trackers: newTrackers)
            newCategories[categoryIndex] = updatedCategory
            print("Добавлен трекер \(tracker.title) в категорию \(categoryTitle)")
        } else {
            let newCategory = TrackerCategory(title: categoryTitle, trackers: [tracker])
            newCategories.append(newCategory)
            print("Создана новая категория \(categoryTitle) с трекером \(tracker.title)")
        }
        categories = newCategories
        collectionView.reloadData()
        updatePlaceholderVisibility()
    }
    
    func deleteTracker(at indexPath: IndexPath) {
        guard indexPath.section < filteredCategories.count else {
            print("Ошибка: индекс секции \(indexPath.section) выходит за пределы \(filteredCategories.count)")
            return
        }
        
        let filteredCategory = filteredCategories[indexPath.section]
        guard indexPath.item < filteredCategory.trackers.count else {
            print("Ошибка: индекс трекера \(indexPath.item) выходит за пределы \(filteredCategory.trackers.count)")
            return
        }
        
        let trackerToDelete = filteredCategory.trackers[indexPath.item]
        guard let categoryIndex = categories.firstIndex(where: { $0.title == filteredCategory.title }) else {
            print("Ошибка: категория не найдена \(filteredCategory.title)")
            return
        }
        
        do {
            try trackerStore.deleteTracker(id: trackerToDelete.id)
            if let categoryIndex = categories.firstIndex(where: { $0.title == filteredCategory.title }) {
                var updatedTrackers = categories[categoryIndex].trackers
                if let trackerIndex = updatedTrackers.firstIndex(where: { $0.id == trackerToDelete.id }) {
                    updatedTrackers.remove(at: trackerIndex)
                    completedTrackers = completedTrackers.filter { $0.id != trackerToDelete.id }
                    
                    if updatedTrackers.isEmpty {
                        categories.remove(at: categoryIndex)
                    } else {
                        categories[categoryIndex] = TrackerCategory(title: filteredCategory.title, trackers: updatedTrackers)
                    }
                    
                    filteredCategories = filterTrackersByDate(currentDate)
                    print("Трекер успешно удален: \(trackerToDelete.title)")
                    collectionView.reloadData()
                    updatePlaceholderVisibility()
                }
            }
        } catch {
            print("Ошибка при удалении трекера: \(error)")
        }
    }
}

extension TrackersViewController: CategoryListControllerDelegate {
    func didSelectCategory(_ category: String) {
        if !categories.contains(where: { $0.title == category }) {
            createCategory(withTitle: category)
        }
    }
    
    func didUpdateCategories(_ categories: [String]) {
        collectionView.reloadData()
        print("Обновлены категории: \(categories)")
    }
}
