import { defineConfig } from 'prisma/config';
import * as dotenv from 'dotenv';

dotenv.config(); // ⭐ สำคัญมาก

export default defineConfig({
  schema: 'prisma/schema.prisma',
});