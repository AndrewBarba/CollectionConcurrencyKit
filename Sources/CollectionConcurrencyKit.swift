/**
 *  CollectionConcurrencyKit
 *  Copyright (c) John Sundell 2021
 *  MIT license, see LICENSE.md file for details
 */

// MARK: - ForEach

public extension Sequence {
    /// Run an async closure for each element within the sequence.
    ///
    /// The closure calls will be performed in order, by waiting for
    /// each call to complete before proceeding with the next one. If
    /// any of the closure calls throw an error, then the iteration
    /// will be terminated and the error rethrown.
    ///
    /// - parameter operation: The closure to run for each element.
    /// - throws: Rethrows any error thrown by the passed closure.
    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }

    /// Run an async closure for each element within the sequence.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter maximumConcurrency: The maximum number of tasks to
    ///   run in parallel. The default is to run all tasks in parallel.
    /// - parameter operation: The closure to run for each element.
    func concurrentForEach(
        withPriority priority: TaskPriority? = nil,
        maximumConcurrency: Int = Int.max,
        _ operation: @escaping (Element) async -> Void
    ) async {
        var iteration = 0

        while true {
            let workingSequence = self.dropFirst(iteration * maximumConcurrency).prefix(maximumConcurrency)

            guard workingSequence.first(where: { _ in true }) != nil else {
                break
            }

            await withTaskGroup(of: Void.self) { group in
                for element in workingSequence {
                    group.addTask(priority: priority) {
                        await operation(element)
                    }
                }

                await group.waitForAll()
            }

            iteration += 1
        }
    }

    /// Run an async closure for each element within the sequence.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed. If any of the closure calls throw an error,
    /// then the first error will be rethrown once all closure calls have
    /// completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter maximumConcurrency: The maximum number of tasks to
    ///   run in parallel. The default is to run all tasks in parallel.
    /// - parameter operation: The closure to run for each element.
    /// - throws: Rethrows any error thrown by the passed closure.
    func concurrentForEach(
        withPriority priority: TaskPriority? = nil,
        maximumConcurrency: Int = Int.max,
        _ operation: @escaping (Element) async throws -> Void
    ) async throws {
        var iteration = 0

        while true {
            let workingSequence = self.dropFirst(iteration * maximumConcurrency).prefix(maximumConcurrency)

            guard workingSequence.first(where: { _ in true }) != nil else {
                break
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                for element in workingSequence {
                    group.addTask(priority: priority) {
                        try await operation(element)
                    }
                }

                try await group.waitForAll()
            }

            iteration += 1
        }
    }
}

// MARK: - Map

public extension Sequence {
    /// Transform the sequence into an array of new values using
    /// an async closure.
    ///
    /// The closure calls will be performed in order, by waiting for
    /// each call to complete before proceeding with the next one. If
    /// any of the closure calls throw an error, then the iteration
    /// will be terminated and the error rethrown.
    ///
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence.
    /// - throws: Rethrows any error thrown by the passed closure.
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }

    /// Transform the sequence into an array of new values using
    /// an async closure.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter maximumConcurrency: The maximum number of tasks to
    ///   run in parallel. The default is to run all tasks in parallel.
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence.
    func concurrentMap<T>(
        withPriority priority: TaskPriority? = nil,
        maximumConcurrency: Int = Int.max,
        _ transform: @escaping (Element) async -> T
    ) async -> [T] {
        var values = [T]()
        var iteration = 0

        while true {
            let workingSequence = self.dropFirst(iteration * maximumConcurrency).prefix(maximumConcurrency)

            guard workingSequence.first(where: { _ in true }) != nil else {
                break
            }

            await withTaskGroup(of: (Int, T).self) { group in
                for (index, element) in workingSequence.enumerated() {
                    group.addTask(priority: priority) {
                        let value = await transform(element)
                        return (index, value)
                    }
                }

                let results = await group
                    .reduce(into: []) { $0.append($1) }
                    .sorted { $0.0 < $1.0 }
                    .map(\.1)

                values.append(contentsOf: results)
            }

            iteration += 1
        }

        return values
    }

    /// Transform the sequence into an array of new values using
    /// an async closure.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed. If any of the closure calls throw an error,
    /// then the first error will be rethrown once all closure calls have
    /// completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter maximumConcurrency: The maximum number of tasks to
    ///   run in parallel. The default is to run all tasks in parallel.
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence.
    /// - throws: Rethrows any error thrown by the passed closure.
    func concurrentMap<T>(
        withPriority priority: TaskPriority? = nil,
        maximumConcurrency: Int = Int.max,
        _ transform: @escaping (Element) async throws -> T
    ) async throws -> [T] {
        var values = [T]()
        var iteration = 0

        while true {
            let workingSequence = self.dropFirst(iteration * maximumConcurrency).prefix(maximumConcurrency)

            guard workingSequence.first(where: { _ in true }) != nil else {
                break
            }

            try await withThrowingTaskGroup(of: (Int, T).self) { group in
                for (index, element) in workingSequence.enumerated() {
                    group.addTask(priority: priority) {
                        let value = try await transform(element)
                        return (index, value)
                    }
                }

                let results = try await group
                    .reduce(into: []) { $0.append($1) }
                    .sorted { $0.0 < $1.0 }
                    .map(\.1)

                values.append(contentsOf: results)
            }

            iteration += 1
        }

        return values
    }
}

// MARK: - CompactMap

public extension Sequence {
    /// Transform the sequence into an array of new values using
    /// an async closure that returns optional values. Only the
    /// non-`nil` return values will be included in the new array.
    ///
    /// The closure calls will be performed in order, by waiting for
    /// each call to complete before proceeding with the next one. If
    /// any of the closure calls throw an error, then the iteration
    /// will be terminated and the error rethrown.
    ///
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   except for the values that were transformed into `nil`.
    /// - throws: Rethrows any error thrown by the passed closure.
    func asyncCompactMap<T>(
        _ transform: (Element) async throws -> T?
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            guard let value = try await transform(element) else {
                continue
            }

            values.append(value)
        }

        return values
    }

    /// Transform the sequence into an array of new values using
    /// an async closure that returns optional values. Only the
    /// non-`nil` return values will be included in the new array.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter maximumConcurrency: The maximum number of tasks to
    ///   run in parallel. The default is to run all tasks in parallel.
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   except for the values that were transformed into `nil`.
    func concurrentCompactMap<T>(
        withPriority priority: TaskPriority? = nil,
        maximumConcurrency: Int = Int.max,
        _ transform: @escaping (Element) async -> T?
    ) async -> [T] {
        var values = [T]()
        var iteration = 0

        while true {
            let workingSequence = self.dropFirst(iteration * maximumConcurrency).prefix(maximumConcurrency)

            guard workingSequence.first(where: { _ in true }) != nil else {
                break
            }

            await withTaskGroup(of: (Int, T?).self) { group in
                for (index, element) in workingSequence.enumerated() {
                    group.addTask(priority: priority) {
                        let value = await transform(element)
                        return (index, value)
                    }
                }

                let results = await group
                    .reduce(into: []) { $0.append($1) }
                    .sorted { $0.0 < $1.0 }
                    .compactMap(\.1)

                values.append(contentsOf: results)
            }

            iteration += 1
        }

        return values
    }

    /// Transform the sequence into an array of new values using
    /// an async closure that returns optional values. Only the
    /// non-`nil` return values will be included in the new array.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed. If any of the closure calls throw an error,
    /// then the first error will be rethrown once all closure calls have
    /// completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter maximumConcurrency: The maximum number of tasks to
    ///   run in parallel. The default is to run all tasks in parallel.
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   except for the values that were transformed into `nil`.
    /// - throws: Rethrows any error thrown by the passed closure.
    func concurrentCompactMap<T>(
        withPriority priority: TaskPriority? = nil,
        maximumConcurrency: Int = Int.max,
        _ transform: @escaping (Element) async throws -> T?
    ) async throws -> [T] {
        var values = [T]()
        var iteration = 0

        while true {
            let workingSequence = self.dropFirst(iteration * maximumConcurrency).prefix(maximumConcurrency)

            guard workingSequence.first(where: { _ in true }) != nil else {
                break
            }

            try await withThrowingTaskGroup(of: (Int, T?).self) { group in
                for (index, element) in workingSequence.enumerated() {
                    group.addTask(priority: priority) {
                        let value = try await transform(element)
                        return (index, value)
                    }
                }

                let results = try await group
                    .reduce(into: []) { $0.append($1) }
                    .sorted { $0.0 < $1.0 }
                    .compactMap(\.1)

                values.append(contentsOf: results)
            }

            iteration += 1
        }

        return values
    }
}

// MARK: - FlatMap

public extension Sequence {
    /// Transform the sequence into an array of new values using
    /// an async closure that returns sequences. The returned sequences
    /// will be flattened into the array returned from this function.
    ///
    /// The closure calls will be performed in order, by waiting for
    /// each call to complete before proceeding with the next one. If
    /// any of the closure calls throw an error, then the iteration
    /// will be terminated and the error rethrown.
    ///
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   with the results of each closure call appearing in-order
    ///   within the returned array.
    /// - throws: Rethrows any error thrown by the passed closure.
    func asyncFlatMap<T: Sequence>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T.Element] {
        var values = [T.Element]()

        for element in self {
            try await values.append(contentsOf: transform(element))
        }

        return values
    }

    /// Transform the sequence into an array of new values using
    /// an async closure that returns sequences. The returned sequences
    /// will be flattened into the array returned from this function.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter maximumConcurrency: The maximum number of tasks to
    ///   run in parallel. The default is to run all tasks in parallel.
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   with the results of each closure call appearing in-order
    ///   within the returned array.
    func concurrentFlatMap<T: Sequence>(
        withPriority priority: TaskPriority? = nil,
        maximumConcurrency: Int = Int.max,
        _ transform: @escaping (Element) async -> T
    ) async -> [T.Element] {
        var values = [T.Element]()
        var iteration = 0

        while true {
            let workingSequence = self.dropFirst(iteration * maximumConcurrency).prefix(maximumConcurrency)

            guard workingSequence.first(where: { _ in true }) != nil else {
                break
            }

            await withTaskGroup(of: (Int, T).self) { group in
                for (index, element) in workingSequence.enumerated() {
                    group.addTask(priority: priority) {
                        let value = await transform(element)
                        return (index, value)
                    }
                }

                let results = await group
                    .reduce(into: []) { $0.append($1) }
                    .sorted { $0.0 < $1.0 }
                    .flatMap(\.1)

                values.append(contentsOf: results)
            }

            iteration += 1
        }

        return values
    }

    /// Transform the sequence into an array of new values using
    /// an async closure that returns sequences. The returned sequences
    /// will be flattened into the array returned from this function.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed. If any of the closure calls throw an error,
    /// then the first error will be rethrown once all closure calls have
    /// completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter maximumConcurrency: The maximum number of tasks to
    ///   run in parallel. The default is to run all tasks in parallel.
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   with the results of each closure call appearing in-order
    ///   within the returned array.
    /// - throws: Rethrows any error thrown by the passed closure.
    func concurrentFlatMap<T: Sequence>(
        withPriority priority: TaskPriority? = nil,
        maximumConcurrency: Int = Int.max,
        _ transform: @escaping (Element) async throws -> T
    ) async throws -> [T.Element] {
        var values = [T.Element]()
        var iteration = 0

        while true {
            let workingSequence = self.dropFirst(iteration * maximumConcurrency).prefix(maximumConcurrency)

            guard workingSequence.first(where: { _ in true }) != nil else {
                break
            }

            try await withThrowingTaskGroup(of: (Int, T).self) { group in
                for (index, element) in workingSequence.enumerated() {
                    group.addTask(priority: priority) {
                        let value = try await transform(element)
                        return (index, value)
                    }
                }

                let results = try await group
                    .reduce(into: []) { $0.append($1) }
                    .sorted { $0.0 < $1.0 }
                    .flatMap(\.1)

                values.append(contentsOf: results)
            }

            iteration += 1
        }

        return values
    }
}
