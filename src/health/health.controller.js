
export default class HealthController {
  static async healthCheck(req, res) {
    try {
      res.status(200).json({
        httpServer: 'up',
        databaseServer: '...'
      })
    } catch (error) {
      console.error('Error in health check...', error);
      res.status(500).json({ message: 'Internal Server Error' });
    }
  }
}
