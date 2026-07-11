import postgresManager from "../database/postgres.manager.js";
export default class HealthRepository {
  static async checkDatbaseStatus() {
    const result = await postgresManager.sql`SELECT 1`;
    return result.length === 1 ? true : false;
  }
}
