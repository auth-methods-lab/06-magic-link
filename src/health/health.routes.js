import { Router } from 'express';
import HealthController from './health.controller.js';

const HealthRouter = new Router();

HealthRouter.get('/', HealthController.healthCheck);

export default HealthRouter;
