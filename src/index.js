import express from 'express';
import cors from 'cors';

import HealthRouter from './health/health.routes.js';
import AuthRoutes from './auth/auth.routes.js';

const app = express();
app.use(cors());
app.use(express.json());

app.use('/health', HealthRouter);
app.use('/auth', AuthRoutes);



app.listen(process.env.PORT, () => {
  console.log(`App listening on http://localhost:${process.env.PORT}`);
})
