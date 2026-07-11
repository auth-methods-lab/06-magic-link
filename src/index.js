import express from 'express';
import cors from 'cors';

import HealthRouter from './health/health.routes.js';

const app = express();
app.use(cors());

app.use('/health', HealthRouter);



app.listen(process.env.PORT, () => {
  console.log(`App listening on http://localhost:${process.env.PORT}`);
})
