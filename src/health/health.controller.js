import HealthService from "./health.service.js";

export default class HealthController {
  static async healthCheck(req, res) {
    try {
      const healthDatabaseResult = await HealthService.healthDatabase();
      res.status(200).json({
        httpServer: 'up',
        databaseServer: healthDatabaseResult ? 'up' : 'down'
      })
    } catch (error) {
      console.error('Error in health check...', error);
      res.status(500).json({ message: 'Internal Server Error' });
    }
  }
}
