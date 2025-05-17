//
//  MenuSelector.swift
//  YAME
//
//  Created by LuoHuanyu on 2025/5/16.
//

import SwiftUI

struct MenuSelector: View {
    @Binding var selectedTask: VisionTask

    var body: some View {
        Menu {
            ForEach(VisionTask.allTasks, id: \.self) { task in
                Button {
                    selectedTask = task
                } label: {
                    HStack {
                        Image(systemName: task.symbol ?? "questionmark.circle")
                        Text(task.name)
                    }
                }
                .accessibilityLabel(task.name)
            }
        } label: {
            if let selectedTaskIcon = selectedTask.symbol {
                Image(systemName: selectedTaskIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityLabel("Change vision task type. Current task is \(selectedTask.name)")
    }
}
