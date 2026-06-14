import Foundation
import HealthKit

extension HKHealthStore {

    /// 从 HealthKit 获取用户年龄（需先完成 dateOfBirth 授权）
    func fetchAge() throws -> Int? {
        let dobComponents = try dateOfBirthComponents()

        guard let dateOfBirth = dobComponents.date,
              let age = Calendar.current.dateComponents(
                  [.year],
                  from: dateOfBirth,
                  to: Date()
              ).year else {
            return nil
        }
        return age
    }
}
