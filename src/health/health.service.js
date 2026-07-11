import HealthRepository from "./health.repository.js";

export default class HealthService {
  static async healthDatabase() {
    return await HealthRepository.checkDatbaseStatus();
  }
}
