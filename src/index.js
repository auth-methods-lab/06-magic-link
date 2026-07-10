import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());



app.listen(process.env.PORT, () => {
  console.log(`App listening on http://localhost:${process.env.PORT}`);
})
