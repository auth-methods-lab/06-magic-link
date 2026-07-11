
export default class AuthController {
  static async sendMagicLink(req, res) {
    try {

    } catch (error) {
      console.error('Error sending magic link...', error);
      res.status(500).json({ message: 'Internal Server Error' });
    }
  }
}
