import SwiftData
import SwiftUI

#if os(iOS)
struct TaskPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    private var activeTasks: [TaskItem] { tasks.filter { $0.status == .nextAction } }

    let onTaskSelected: (TaskItem?) -> Void

    @State private var searchText = ""

    var filteredTasks: [TaskItem] {
        if searchText.isEmpty {
            return activeTasks
        } else {
            return activeTasks.filter { task in
                task.title.localizedCaseInsensitiveContains(searchText) ||
                task.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Active Tasks")) {
                    Button {
                        onTaskSelected(nil)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.secondary)
                            Text("No Task")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Clear selection")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    ForEach(filteredTasks) { task in
                        Button {
                            onTaskSelected(task)
                            dismiss()
                        } label: {
                            TaskRowView(task: task)
                                .foregroundColor(.primary)
                        }
                    }
                }

                if filteredTasks.isEmpty && !searchText.isEmpty {
                    Section {
                        Text("No tasks match your search")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.themeBackground)
            .searchable(text: $searchText, prompt: "Search tasks")
            .navigationTitle("Select Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TaskRowView: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.headline)

            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Text(task.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#endif
